-- 020_bot_delayed_match.sql
-- Delays bot matches by a random interval between 20 and 180 minutes instead of matching instantly.

-- 1. Table to store pending bot matches
create table if not exists public.bot_pending_matches (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  comment text,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint bot_pending_matches_unique unique(bot_id, user_id)
);

alter table public.bot_pending_matches enable row level security;

-- 2. Trigger function on public.likes: queue the match with a 20-180 minute random delay
create or replace function public.bot_accept_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  bot public.profiles;
  delay_minutes integer;
begin
  -- Only trigger when target is an active bot
  select * into bot from public.profiles where id = new.to_user and is_bot and not blocked;
  if not found then return new; end if;

  -- Don't match bot to bot
  if exists (select 1 from public.profiles where id = new.from_user and is_bot) then
    return new;
  end if;

  -- If already matched, nothing to do
  if exists (
    select 1 from public.matches
     where (user_a = least(new.from_user, new.to_user)
            and user_b = greatest(new.from_user, new.to_user))
  ) then
    return new;
  end if;

  -- Random delay between 20 and 180 minutes
  delay_minutes := floor(20 + random() * 161)::int;

  -- Queue the match to be created after delay_minutes
  insert into public.bot_pending_matches (bot_id, user_id, comment, scheduled_at)
  values (new.to_user, new.from_user, new.comment, now() + (delay_minutes || ' minutes')::interval)
  on conflict (bot_id, user_id) do update
    set comment = coalesce(excluded.comment, bot_pending_matches.comment);

  return new;
end $$;

drop trigger if exists likes_bot_accept on public.likes;
create trigger likes_bot_accept after insert on public.likes
  for each row execute function public.bot_accept_like();

-- 3. Function to process due bot matches
create or replace function public.process_due_bot_matches()
returns void language plpgsql security definer set search_path = public as $$
declare
  pm record;
  bot public.profiles;
  mid uuid;
begin
  for pm in
    delete from public.bot_pending_matches
     where scheduled_at <= now()
     returning *
  loop
    select * into bot from public.profiles where id = pm.bot_id and is_bot and not blocked;
    if found then
      -- Insert reciprocal like from bot to user (this fires likes_make_match trigger)
      insert into public.likes (from_user, to_user, target)
      values (pm.bot_id, pm.user_id, 'profile')
      on conflict do nothing;

      -- Fetch the newly created match id
      select id into mid from public.matches
       where user_a = least(pm.user_id, pm.bot_id)
         and user_b = greatest(pm.user_id, pm.bot_id);

      -- Send opening message or note reply
      if mid is not null then
        if coalesce(pm.comment, '') <> '' then
          if not exists (select 1 from public.messages where match_id = mid) then
            insert into public.messages (match_id, sender, body)
            values (mid, pm.user_id, left(pm.comment, 2000));
          end if;
        else
          if not exists (select 1 from public.messages where match_id = mid) then
            insert into public.messages (match_id, sender, body)
            values (mid, pm.bot_id, public.bot_reply_text(bot, '', true));
          end if;
        end if;
      end if;
    end if;
  end loop;
end $$;

-- 4. Update my_matches to automatically process due bot matches
drop function if exists public.my_matches();

create or replace function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language plpgsql volatile security definer set search_path = public as $$
begin
  -- Process any pending bot matches whose scheduled time has arrived
  perform public.process_due_bot_matches();

  return query
    select m.id, m.created_at, p.id, p.name,
           coalesce(extract(year from age(p.birthday))::int, 0),
           p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
           p.prompt_label, p.prompt_answer, p.photos, p.verified,
           p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
           p.voice_seconds
    from public.matches m
    join public.profiles p
      on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
    where auth.uid() in (m.user_a, m.user_b) and public.visible_to_me(p)
    order by m.created_at desc;
end;
$$;

revoke all on function public.process_due_bot_matches() from public, anon;
grant execute on function public.process_due_bot_matches() to authenticated, service_role;

revoke all on function public.my_matches() from public, anon;
grant execute on function public.my_matches() to authenticated;

-- 5. If pg_cron is available, schedule it to run every 2 minutes as well
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('process_due_bot_matches');
    exception when others then null;
    end;
    perform cron.schedule('process_due_bot_matches', '*/2 * * * *', 'select public.process_due_bot_matches()');
  end if;
exception when others then
  null;
end $$;

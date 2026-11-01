-- 028_bot_delayed_match_and_reply.sql
-- 1. Realistic bot matching:
--    - No instant match on like or direct message.
--    - ~65% match rate (realistic: not every bot matches back).
--    - Matches are delayed by a random 20 to 2000 seconds.
-- 2. Realistic bot replies:
--    - Direct message notes and chat messages get replies delayed by random 20 to 2000 seconds.

-- 1. Ensure table for pending bot matches exists
create table if not exists public.bot_pending_matches (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  comment text,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint bot_pending_matches_unique unique(bot_id, user_id)
);

create index if not exists idx_bot_pending_matches_scheduled_at
  on public.bot_pending_matches (scheduled_at);

alter table public.bot_pending_matches enable row level security;

-- 2. Ensure table for pending bot replies exists
create table if not exists public.bot_pending_replies (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  bot_id uuid not null references public.profiles(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reply_body text not null,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint bot_pending_replies_match_unique unique(match_id)
);

create index if not exists idx_bot_pending_replies_scheduled_at
  on public.bot_pending_replies (scheduled_at);

alter table public.bot_pending_replies enable row level security;

-- 3. Trigger on public.likes:
-- When a user likes a bot or sends a direct message, DO NOT match instantly.
-- Apply realistic match rate (~65%) and delay match by random 20-2000 seconds.
create or replace function public.bot_accept_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  bot public.profiles;
  delay_sec integer;
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

  -- Realistic match rate: ~65% match back, ~35% pass / don't match
  if random() > 0.65 then
    return new;
  end if;

  -- Random delay between 20 and 2000 seconds
  delay_sec := floor(20 + random() * 1981)::int;

  -- Queue the match to be created after delay_sec
  insert into public.bot_pending_matches (bot_id, user_id, comment, scheduled_at)
  values (new.to_user, new.from_user, new.comment, now() + (delay_sec || ' seconds')::interval)
  on conflict (bot_id, user_id) do update
    set comment = coalesce(excluded.comment, bot_pending_matches.comment),
        scheduled_at = least(bot_pending_matches.scheduled_at, excluded.scheduled_at);

  return new;
end $$;

drop trigger if exists likes_bot_accept on public.likes;
create trigger likes_bot_accept after insert on public.likes
  for each row execute function public.bot_accept_like();

-- 4. Function to process due bot matches
create or replace function public.process_due_bot_matches()
returns void language plpgsql security definer set search_path = public as $$
declare
  pm record;
  bot public.profiles;
  mid uuid;
  reply_delay_sec integer;
begin
  for pm in
    delete from public.bot_pending_matches
     where id in (
       select id from public.bot_pending_matches
        where scheduled_at <= now()
        for update skip locked
     )
     returning *
  loop
    select * into bot from public.profiles where id = pm.bot_id and is_bot and not blocked;
    if found then
      -- Insert reciprocal like from bot to user (this fires match_on_mutual_like trigger to create the match)
      insert into public.likes (from_user, to_user, target)
      values (pm.bot_id, pm.user_id, 'profile')
      on conflict do nothing;

      -- Fetch the newly created match id
      select id into mid from public.matches
       where user_a = least(pm.user_id, pm.bot_id)
         and user_b = greatest(pm.user_id, pm.bot_id);

      if mid is not null then
        if coalesce(pm.comment, '') <> '' then
          -- Direct message: insert into messages.
          -- This insert will trigger messages_bot_answer, queueing the bot's reply with 20-2000s delay.
          if not exists (select 1 from public.messages where match_id = mid) then
            insert into public.messages (match_id, sender, body)
            values (mid, pm.user_id, left(pm.comment, 2000));
          end if;
        else
          -- No direct message: schedule bot's opening greeting with random 20-2000s delay
          reply_delay_sec := floor(20 + random() * 1981)::int;
          insert into public.bot_pending_replies (match_id, bot_id, user_id, reply_body, scheduled_at)
          values (mid, pm.bot_id, pm.user_id, public.bot_reply_text(bot, '', true), now() + (reply_delay_sec || ' seconds')::interval)
          on conflict (match_id) do update
            set reply_body = excluded.reply_body,
                scheduled_at = excluded.scheduled_at;
        end if;
      end if;
    end if;
  end loop;
end $$;

revoke all on function public.process_due_bot_matches() from public, anon;
grant execute on function public.process_due_bot_matches() to authenticated, service_role;

-- 5. Trigger on public.messages:
-- Delay bot replies to messages by a random 20 to 2000 seconds.
create or replace function public.bot_answer_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  other uuid;
  bot public.profiles;
  delay_sec integer;
  reply text;
begin
  -- Don't answer messages sent by bots
  if exists (select 1 from public.profiles where id = new.sender and is_bot) then
    return new;
  end if;

  -- Find the recipient in the match
  select case when m.user_a = new.sender then m.user_b else m.user_a end
    into other from public.matches m where m.id = new.match_id;

  -- Verify recipient is an active bot
  select * into bot from public.profiles where id = other and is_bot and not blocked;
  if not found then return new; end if;

  -- Generate reply text
  reply := public.bot_reply_text(bot, new.body, false);

  -- Delay reply by a random 20-2000 seconds
  delay_sec := floor(20 + random() * 1981)::int;

  -- Queue or update pending reply
  insert into public.bot_pending_replies (match_id, bot_id, user_id, reply_body, scheduled_at)
  values (new.match_id, other, new.sender, reply, now() + (delay_sec || ' seconds')::interval)
  on conflict (match_id) do update
    set reply_body = excluded.reply_body,
        scheduled_at = excluded.scheduled_at;

  return new;
end $$;

drop trigger if exists messages_bot_answer on public.messages;
create trigger messages_bot_answer after insert on public.messages
  for each row execute function public.bot_answer_message();

-- 6. Function to process due bot replies
create or replace function public.process_due_bot_replies()
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  for r in
    delete from public.bot_pending_replies
     where id in (
       select id from public.bot_pending_replies
        where scheduled_at <= now()
        for update skip locked
     )
     returning *
  loop
    insert into public.messages (match_id, sender, body)
    values (r.match_id, r.bot_id, r.reply_body);
  end loop;
end $$;

revoke all on function public.process_due_bot_replies() from public, anon;
grant execute on function public.process_due_bot_replies() to authenticated, service_role;

-- 7. Combined processor for due bot events (matches + replies)
create or replace function public.process_due_bot_events()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.process_due_bot_matches();
  perform public.process_due_bot_replies();
end $$;

revoke all on function public.process_due_bot_events() from public, anon;
grant execute on function public.process_due_bot_events() to authenticated, service_role;

-- 8. Update my_matches to process both due matches and due replies
create or replace function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language plpgsql volatile security definer set search_path = public as $$
begin
  -- Automatically process any due bot matches and replies
  perform public.process_due_bot_events();

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

revoke all on function public.my_matches() from public, anon;
grant execute on function public.my_matches() to authenticated;

-- 9. Update pg_cron to schedule process_due_bot_events
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('process_due_bot_matches');
    exception when others then null;
    end;
    begin
      perform cron.unschedule('process_due_bot_replies');
    exception when others then null;
    end;
    begin
      perform cron.unschedule('process_due_bot_events');
    exception when others then null;
    end;
    perform cron.schedule('process_due_bot_events', '* * * * *', 'select public.process_due_bot_events()');
  end if;
exception when others then
  null;
end $$;

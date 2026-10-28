-- Everlane bot profiles: admin-made profiles, with photos added by hand,
-- for QA, demos and store screenshots. Bots are always test accounts, so
-- only other test accounts ever see them (see visible_to_me in 007); real
-- members never do. Bots can't sign in: they have no password or provider.

alter table public.profiles
  add column if not exists is_bot boolean not null default false;
alter table public.profiles drop constraint if exists bots_are_test;
alter table public.profiles add constraint bots_are_test check (not is_bot or is_test);

-- Members can't make themselves a bot either.
create or replace function public.keep_block_admin_only()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.blocked := false; new.blocked_reason := ''; new.blocked_at := null;
      new.suspended_until := null; new.warnings := 0; new.warning := '';
      new.warned_at := null; new.plan := ''; new.is_test := false;
      new.verified := false; new.is_bot := false;
    else
      new.blocked := old.blocked;
      new.blocked_reason := old.blocked_reason;
      new.blocked_at := old.blocked_at;
      new.suspended_until := old.suspended_until;
      new.warnings := old.warnings;
      -- acknowledge_warning() may clear the message, nothing else.
      if not (current_setting('everlane.ack_warning', true) = 'on' and new.warning = '') then
        new.warning := old.warning;
      end if;
      new.warned_at := old.warned_at;
      new.plan := old.plan;
      new.is_test := old.is_test;
      new.verified := old.verified;
      new.is_bot := old.is_bot;
    end if;
  end if;
  return new;
end $$;

-- Admins upload a bot's photos into the bot's folder (<bot id>/...).
drop policy if exists "Admins upload any photo" on storage.objects;
create policy "Admins upload any photo" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and public.is_admin());
drop policy if exists "Admins update any photo" on storage.objects;
create policy "Admins update any photo" on storage.objects
  for update to authenticated
  using (bucket_id = 'photos' and public.is_admin());

-- Storage only deletes (or overwrites) objects the caller can select, so
-- without these every photo delete quietly did nothing: Photo queue
-- rejections, members removing a photo, and bot clean-up.
drop policy if exists "Members read their own photos" on storage.objects;
create policy "Members read their own photos" on storage.objects
  for select to authenticated
  using (bucket_id in ('photos', 'voice') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Admins read any photo" on storage.objects;
create policy "Admins read any photo" on storage.objects
  for select to authenticated
  using (bucket_id in ('photos', 'voice') and public.is_admin());

create or replace function public.admin_bots()
returns setof public.profiles
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query select * from public.profiles where is_bot order by updated_at desc;
end $$;

-- Creates a bot when [bot] is null, otherwise updates it. [data] carries the
-- profile fields; photos are storage paths in the "photos" bucket, uploaded
-- by the panel first. An admin's own photos skip the review queue.
create or replace function public.admin_save_bot(bot uuid, data jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  creating boolean := bot is null;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  if creating then
    bot := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            created_at, updated_at, confirmation_token, recovery_token,
                            email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', bot, 'authenticated', 'authenticated',
            'bot-' || bot || '@bots.everlane.invalid', '', now(),
            '{"provider": "bot", "providers": []}', '{"bot": true}',
            now(), now(), '', '', '', '');
    insert into public.profiles (id, is_bot, is_test, onboarded, posted)
    values (bot, true, true, true, true);
  elsif not exists (select 1 from public.profiles where id = bot and is_bot) then
    raise exception 'not a bot';
  end if;

  update public.profiles set
    name = coalesce(data->>'name', name),
    birthday = coalesce((data->>'birthday')::date, birthday),
    gender = coalesce(data->>'gender', gender),
    interested_in = coalesce(data->>'interested_in', interested_in),
    city = coalesce(data->>'city', city),
    job = coalesce(data->>'job', job),
    bio = coalesce(data->>'bio', bio),
    looking_for = coalesce(data->>'looking_for', looking_for),
    interests = coalesce(array(select jsonb_array_elements_text(data->'interests')), interests),
    prompt_label = coalesce(data->>'prompt_label', prompt_label),
    prompt_answer = coalesce(data->>'prompt_answer', prompt_answer),
    height_cm = case when data ? 'height_cm' then (data->>'height_cm')::int else height_cm end,
    languages = coalesce(array(select jsonb_array_elements_text(data->'languages')), languages),
    photos = coalesce(array(select jsonb_array_elements_text(data->'photos')), photos),
    updated_at = now()
  where id = bot;

  update public.photo_reviews
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where user_id = bot and status = 'pending';

  perform public.log_admin(case when creating then 'bot_create' else 'bot_update' end,
                           bot, jsonb_build_object('name', data->>'name'));
  return bot;
end $$;

-- Deletes the bot's account and profile; the panel removes its photo files.
create or replace function public.admin_delete_bot(bot uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  bot_name text;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select name into bot_name from public.profiles where id = bot and is_bot;
  if not found then raise exception 'not a bot'; end if;
  delete from auth.users where id = bot;
  perform public.log_admin('bot_delete', bot, jsonb_build_object('name', bot_name));
end $$;

-- Kill switch: hides every bot at once (as blocked), or brings them back.
create or replace function public.admin_set_bots_live(live boolean)
returns int language plpgsql security definer set search_path = public as $$
declare
  changed int;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  update public.profiles
     set blocked = not live,
         blocked_reason = case when live then '' else 'Bots switched off' end,
         blocked_at = case when live then null else now() end
   where is_bot and blocked = live;
  get diagnostics changed = row_count;
  perform public.log_admin(case when live then 'bots_on' else 'bots_off' end, null,
                           jsonb_build_object('count', changed));
  return changed;
end $$;

-- Bots stay out of the members list and the member counts.
create or replace function public.admin_members()
returns table (id uuid, email text, phone text, joined_at timestamptz,
               last_sign_in_at timestamptz, provider text, name text, age int,
               gender text, interested_in text, city text, job text, bio text,
               looking_for text, height_cm int, languages text[],
               interests text[], photos text[], onboarded boolean,
               verified boolean, blocked boolean, blocked_reason text,
               suspended_until timestamptz, warnings int, plan text,
               is_test boolean, reports_against bigint,
               likes_sent bigint, likes_received bigint, matches bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select u.id, u.email::text, u.phone::text, u.created_at, u.last_sign_in_at,
         coalesce(u.raw_app_meta_data->>'provider', ''),
         coalesce(p.name, ''), coalesce(extract(year from age(p.birthday))::int, 0),
         coalesce(p.gender, ''), coalesce(p.interested_in, ''), coalesce(p.city, ''),
         coalesce(p.job, ''), coalesce(p.bio, ''), coalesce(p.looking_for, ''),
         p.height_cm, coalesce(p.languages, '{}'), coalesce(p.interests, '{}'),
         coalesce(p.photos, '{}'), coalesce(p.onboarded, false),
         coalesce(p.verified, false), coalesce(p.blocked, false),
         coalesce(p.blocked_reason, ''), p.suspended_until,
         coalesce(p.warnings, 0), coalesce(p.plan, ''), coalesce(p.is_test, false),
         (select count(*) from public.reports r where r.reported = u.id),
         (select count(*) from public.likes l where l.from_user = u.id),
         (select count(*) from public.likes l where l.to_user = u.id),
         (select count(*) from public.matches m where u.id in (m.user_a, m.user_b))
  from auth.users u
  left join public.profiles p on p.id = u.id
  where not coalesce(p.is_bot, false)
  order by u.created_at desc;
end $$;

create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  today timestamptz := date_trunc('day', now());
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'accounts', (select count(*) from auth.users u
                 where not exists (select 1 from public.profiles p where p.id = u.id and p.is_bot)),
    'profiles', (select count(*) from public.profiles where not is_test),
    'onboarded', (select count(*) from public.profiles where onboarded and not is_test),
    'blocked', (select count(*) from public.profiles where blocked),
    'suspended', (select count(*) from public.profiles where suspended_until > now()),
    'test_accounts', (select count(*) from public.profiles where is_test and not is_bot),
    'bots', (select count(*) from public.profiles where is_bot),
    'signups_today', (select count(*) from auth.users where created_at >= today
                        and raw_app_meta_data->>'provider' is distinct from 'bot'),
    'signups_7d', (select count(*) from auth.users where created_at >= now() - interval '7 days'
                     and raw_app_meta_data->>'provider' is distinct from 'bot'),
    -- Active today: signed in, saved their profile, liked, passed or messaged.
    'dau', (select count(distinct u) from (
              select id u from auth.users where last_sign_in_at >= today
              union select id from public.profiles where updated_at >= today and not is_bot
              union select from_user from public.likes where created_at >= today
              union select from_user from public.passes where created_at >= today
              union select sender from public.messages where created_at >= today) a),
    'men', (select count(*) from public.profiles where gender = 'Man' and onboarded and not is_test),
    'women', (select count(*) from public.profiles where gender = 'Woman' and onboarded and not is_test),
    'other_gender', (select count(*) from public.profiles
                     where gender not in ('Man', 'Woman') and onboarded and not is_test),
    'paid_members', (select count(*) from public.profiles
                     where plan in ('plus', 'gold', 'platinum') and not is_test),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'pending_photos', (select count(*) from public.photo_reviews r
                       join public.profiles p on p.id = r.user_id
                       where r.status = 'pending' and r.path = any (p.photos)),
    'likes', (select count(*) from public.likes),
    'matches', (select count(*) from public.matches),
    'messages', (select count(*) from public.messages));
end $$;

revoke all on function public.admin_bots() from public, anon;
revoke all on function public.admin_save_bot(uuid, jsonb) from public, anon;
revoke all on function public.admin_delete_bot(uuid) from public, anon;
grant execute on function public.admin_bots() to authenticated;
grant execute on function public.admin_save_bot(uuid, jsonb) to authenticated;
grant execute on function public.admin_delete_bot(uuid) to authenticated;
revoke all on function public.admin_set_bots_live(boolean) from public, anon;
grant execute on function public.admin_set_bots_live(boolean) to authenticated;

-- Everlane user management: full profile edits, shadow-bans, restorable
-- deletes, boosts, timed premium, force logout, email / phone changes,
-- login history with multi-account hints, a read-only "view as member"
-- and a GDPR export. Every action lands in the audit log.

alter table public.profiles
  -- Hidden from everyone else (Discover, Likes, matches) without being told.
  add column if not exists shadow_banned boolean not null default false,
  -- Deleted by an admin: blocked and restorable until purged for good.
  add column if not exists deleted_at timestamptz,
  -- Shown first in Discover until then.
  add column if not exists boosted_until timestamptz,
  -- An admin-granted plan ends then; null means it doesn't expire.
  add column if not exists plan_until timestamptz;

create or replace function public.keep_block_admin_only()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.blocked := false; new.blocked_reason := ''; new.blocked_at := null;
      new.suspended_until := null; new.warnings := 0; new.warning := '';
      new.warned_at := null; new.plan := ''; new.is_test := false;
      new.verified := false; new.is_bot := false; new.shadow_banned := false;
      new.deleted_at := null; new.boosted_until := null; new.plan_until := null;
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
      new.shadow_banned := old.shadow_banned;
      new.deleted_at := old.deleted_at;
      new.boosted_until := old.boosted_until;
      new.plan_until := old.plan_until;
    end if;
  end if;
  return new;
end $$;

-- Shadow-banned members keep using the app, but nobody else sees them.
create or replace function public.visible_to_me(p public.profiles)
returns boolean language sql stable security definer set search_path = public as $$
  select not p.blocked
     and not p.shadow_banned
     and coalesce(p.suspended_until <= now(), true)
     and p.is_test = coalesce((select is_test from public.profiles where id = auth.uid()), false)
$$;

-- Boosted profiles come first.
create or replace function public.discover_members(max_results int default 50)
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  where p.id <> me.id
    and p.onboarded and public.visible_to_me(p)
    and cardinality(p.photos) > 0
    and not exists (select 1 from public.likes l
                    where l.from_user = me.id and l.to_user = p.id)
    and not exists (select 1 from public.passes s
                    where s.from_user = me.id and s.to_user = p.id)
    and not exists (select 1 from public.matches m
                    where (m.user_a, m.user_b) in ((me.id, p.id), (p.id, me.id)))
    and (me.interested_in in ('', 'Everyone')
         or (me.interested_in = 'Women' and p.gender = 'Woman')
         or (me.interested_in = 'Men' and p.gender = 'Man'))
    and (p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by coalesce(p.boosted_until > now(), false) desc, p.updated_at desc
  limit max_results
$$;

-- ---------------------------------------------------------------------------
-- Profile edits, shared by members and bots. Only for admin functions.
-- ---------------------------------------------------------------------------
create or replace function public.apply_profile_fields(target uuid, data jsonb)
returns void language sql security definer set search_path = public as $$
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
  where id = target
$$;
revoke all on function public.apply_profile_fields(uuid, jsonb) from public, anon, authenticated;

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
  perform public.apply_profile_fields(bot, data);
  update public.photo_reviews
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where user_id = bot and status = 'pending';
  perform public.log_admin(case when creating then 'bot_create' else 'bot_update' end,
                           bot, jsonb_build_object('name', data->>'name'));
  return bot;
end $$;

-- An admin's edit to a member's profile. Photos an admin adds skip review.
create or replace function public.admin_edit_profile(member uuid, data jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  before public.profiles;
  changed text[];
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select * into before from public.profiles where id = member and not is_bot;
  if not found then raise exception 'no such member'; end if;
  perform public.apply_profile_fields(member, data);
  update public.photo_reviews
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where user_id = member and status = 'pending'
     and not (path = any (before.photos));
  select array_agg(k) into changed from jsonb_object_keys(data) k
   where to_jsonb(before)->k is distinct from data->k;
  perform public.log_admin('edit_profile', member, jsonb_build_object('fields', coalesce(changed, '{}')));
end $$;

-- ---------------------------------------------------------------------------
-- Moderation actions, now with shadow-bans, deletes, boosts and timed plans.
-- ---------------------------------------------------------------------------
create or replace function public.admin_moderate(
  member uuid, action text, reason text default '', days int default 0, value text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  insert into public.profiles (id) values (member) on conflict (id) do nothing;
  case action
    when 'verify' then update public.profiles set verified = true where id = member;
    when 'unverify' then update public.profiles set verified = false where id = member;
    when 'warn' then
      if coalesce(trim(reason), '') = '' then raise exception 'a warning needs a message'; end if;
      update public.profiles
         set warnings = warnings + 1, warning = reason, warned_at = now()
       where id = member;
    when 'suspend' then
      if days not between 1 and 365 then raise exception 'suspend for 1 to 365 days'; end if;
      update public.profiles set suspended_until = now() + make_interval(days => days)
       where id = member;
    when 'unsuspend' then update public.profiles set suspended_until = null where id = member;
    -- days > 0 makes the plan run out after that many days.
    when 'set_plan' then
      update public.profiles
         set plan = coalesce(value, ''),
             plan_until = case when days > 0 and coalesce(value, '') <> ''
                               then now() + make_interval(days => days) end
       where id = member;
    when 'mark_test' then update public.profiles set is_test = true where id = member;
    when 'unmark_test' then update public.profiles set is_test = false where id = member;
    when 'shadow_ban' then update public.profiles set shadow_banned = true where id = member;
    when 'unshadow_ban' then update public.profiles set shadow_banned = false where id = member;
    when 'boost' then
      if days not between 1 and 30 then raise exception 'boost for 1 to 30 days'; end if;
      update public.profiles
         set boosted_until = greatest(coalesce(boosted_until, now()), now()) + make_interval(days => days)
       where id = member;
    when 'unboost' then update public.profiles set boosted_until = null where id = member;
    -- Deleting blocks the account (the app signs them out) and keeps the data
    -- so it can be restored; admin_purge_member removes it for good.
    when 'delete' then
      update public.profiles
         set deleted_at = now(), blocked = true, blocked_at = now(),
             blocked_reason = coalesce(nullif(trim(reason), ''), 'Deleted by an admin')
       where id = member;
      delete from auth.sessions where user_id = member;
    when 'restore' then
      update public.profiles
         set deleted_at = null, blocked = false, blocked_at = null, blocked_reason = ''
       where id = member;
    when 'logout' then delete from auth.sessions where user_id = member;
    else raise exception 'unknown action %', action;
  end case;
  perform public.log_admin(action, member, jsonb_build_object(
    'reason', coalesce(reason, ''), 'days', days, 'value', coalesce(value, '')));
end $$;

-- Removes a deleted account for good. The panel then removes its files.
create or replace function public.admin_purge_member(member uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  p public.profiles;
  files jsonb;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select * into p from public.profiles where id = member;
  if not found or p.deleted_at is null then raise exception 'delete the account first'; end if;
  if member = auth.uid() then raise exception 'you can''t purge your own account'; end if;
  files := jsonb_build_object(
    'photos', to_jsonb(p.photos),
    'voice', to_jsonb(array_remove(array[p.voice_path], '')),
    'verifications', coalesce((select jsonb_agg(f) from public.verification_requests r,
                                unnest(r.frames) f where r.user_id = member), '[]'));
  perform public.log_admin('purge', member, jsonb_build_object('name', p.name));
  delete from auth.users where id = member;
  return files;
end $$;

-- ---------------------------------------------------------------------------
-- Sign-in details: email and phone changes.
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_contact(member uuid, new_email text, new_phone text)
returns void language plpgsql security definer set search_path = auth, public as $$
declare
  old_email text;
  old_phone text;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select email, phone into old_email, old_phone from auth.users where id = member;
  if not found then raise exception 'no such account'; end if;
  new_email := nullif(lower(trim(new_email)), '');
  new_phone := nullif(regexp_replace(coalesce(new_phone, ''), '[^0-9]', '', 'g'), '');
  if new_email is not null and new_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'that email doesn''t look right';
  end if;
  if new_email is distinct from old_email then
    if new_email is not null and exists (select 1 from auth.users where email = new_email and id <> member) then
      raise exception 'another account already uses that email';
    end if;
    update auth.users set email = new_email, email_confirmed_at = case when new_email is null then null else now() end,
                          updated_at = now()
     where id = member;
    update auth.identities
       set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(coalesce(new_email, ''))), updated_at = now()
     where user_id = member and provider = 'email';
  end if;
  if new_phone is distinct from old_phone then
    if new_phone is not null and exists (select 1 from auth.users where phone = new_phone and id <> member) then
      raise exception 'another account already uses that phone number';
    end if;
    update auth.users set phone = new_phone, phone_confirmed_at = case when new_phone is null then null else now() end,
                          updated_at = now()
     where id = member;
    update auth.identities
       set identity_data = jsonb_set(identity_data, '{phone}', to_jsonb(coalesce(new_phone, ''))), updated_at = now()
     where user_id = member and provider = 'phone';
  end if;
  perform public.log_admin('set_contact', member, jsonb_build_object(
    'email', jsonb_build_object('from', old_email, 'to', new_email),
    'phone', jsonb_build_object('from', old_phone, 'to', new_phone)));
end $$;

-- ---------------------------------------------------------------------------
-- Login history. Sessions vanish on sign-out, so each one is copied here.
-- ---------------------------------------------------------------------------
create table if not exists public.login_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  ip inet,
  user_agent text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists login_events_user_idx on public.login_events (user_id, created_at desc);
create index if not exists login_events_ip_idx on public.login_events (ip);
alter table public.login_events enable row level security;

create or replace function public.record_login()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.login_events (user_id, ip, user_agent, created_at)
  values (new.user_id, new.ip, coalesce(new.user_agent, ''), coalesce(new.created_at, now()));
  return new;
end $$;
drop trigger if exists sessions_record_login on auth.sessions;
create trigger sessions_record_login after insert on auth.sessions
  for each row execute function public.record_login();

insert into public.login_events (user_id, ip, user_agent, created_at)
select s.user_id, s.ip, coalesce(s.user_agent, ''), s.created_at from auth.sessions s
where not exists (select 1 from public.login_events e where e.user_id = s.user_id and e.created_at = s.created_at);

-- Sign-ins, open sessions, and other accounts that signed in from the same IPs.
create or replace function public.admin_member_security(member uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'logins', coalesce((select jsonb_agg(e order by e.created_at desc) from (
        select host(ip) ip, user_agent, created_at from public.login_events
        where user_id = member order by created_at desc limit 50) e), '[]'),
    'open_sessions', (select count(*) from auth.sessions where user_id = member),
    'shared', coalesce((select jsonb_agg(s) from (
        select o.user_id id, coalesce(p.name, '') name, coalesce(u.email, u.phone, '') contact,
               coalesce(p.blocked, false) blocked, array_agg(distinct host(o.ip)) ips
        from public.login_events mine
        join public.login_events o on o.ip = mine.ip and o.user_id <> member
        join auth.users u on u.id = o.user_id
        left join public.profiles p on p.id = o.user_id
        where mine.user_id = member and mine.ip is not null
        group by o.user_id, p.name, u.email, u.phone, p.blocked
        limit 25) s), '[]'));
end $$;

-- What the member sees: their matches with the latest message, and who likes them.
create or replace function public.admin_view_as(member uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  perform public.log_admin('view_as', member, '{}');
  return jsonb_build_object(
    'matches', coalesce((select jsonb_agg(x order by x.last_at desc nulls last) from (
        select o.id, o.name, o.photos[1] photo, m.created_at matched_at,
               (select body from public.messages where match_id = m.id order by created_at desc limit 1) last_message,
               (select created_at from public.messages where match_id = m.id order by created_at desc limit 1) last_at,
               (select count(*) from public.messages where match_id = m.id) messages
        from public.matches m
        join public.profiles o on o.id = case when m.user_a = member then m.user_b else m.user_a end
        where member in (m.user_a, m.user_b)) x), '[]'),
    'likes_received', coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select o.id, o.name, o.photos[1] photo, l.created_at
        from public.likes l join public.profiles o on o.id = l.from_user
        where l.to_user = member
          and not exists (select 1 from public.matches m
                          where (m.user_a, m.user_b) in ((member, o.id), (o.id, member)))
        limit 100) x), '[]'),
    'likes_sent', (select count(*) from public.likes where from_user = member),
    'passes', (select count(*) from public.passes where from_user = member));
end $$;

-- Everything stored about a member, as one JSON document (GDPR access request).
create or replace function public.admin_export_member(member uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  doc jsonb;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  select jsonb_build_object(
    'exported_at', now(),
    'account', (select jsonb_build_object('id', id, 'email', email, 'phone', phone,
                  'created_at', created_at, 'last_sign_in_at', last_sign_in_at,
                  'provider', raw_app_meta_data->>'provider') from auth.users where id = member),
    'profile', (select to_jsonb(p) from public.profiles p where id = member),
    'likes_sent', coalesce((select jsonb_agg(to_jsonb(l)) from public.likes l where from_user = member), '[]'),
    'likes_received', coalesce((select jsonb_agg(to_jsonb(l)) from public.likes l where to_user = member), '[]'),
    'passes', coalesce((select jsonb_agg(to_jsonb(s)) from public.passes s where from_user = member), '[]'),
    'matches', coalesce((select jsonb_agg(to_jsonb(m)) from public.matches m where member in (user_a, user_b)), '[]'),
    'messages_sent', coalesce((select jsonb_agg(to_jsonb(x)) from public.messages x where sender = member), '[]'),
    'reports_made', coalesce((select jsonb_agg(to_jsonb(r)) from public.reports r where reporter = member), '[]'),
    'reports_against', coalesce((select jsonb_agg(to_jsonb(r)) from public.reports r where reported = member), '[]'),
    'verification_requests', coalesce((select jsonb_agg(to_jsonb(v)) from public.verification_requests v where user_id = member), '[]'),
    'area_visits', coalesce((select jsonb_agg(to_jsonb(a)) from public.area_visits a where user_id = member), '[]'),
    'logins', coalesce((select jsonb_agg(to_jsonb(e)) from public.login_events e where user_id = member), '[]'))
  into doc;
  perform public.log_admin('export', member, '{}');
  return doc;
end $$;

-- ---------------------------------------------------------------------------
-- The members list gains the new fields.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_members();
create function public.admin_members()
returns table (id uuid, email text, phone text, joined_at timestamptz,
               last_sign_in_at timestamptz, provider text, name text, age int,
               birthday date, gender text, interested_in text, city text, job text,
               bio text, looking_for text, height_cm int, languages text[],
               interests text[], prompt_label text, prompt_answer text,
               photos text[], onboarded boolean, verified boolean,
               blocked boolean, blocked_reason text, suspended_until timestamptz,
               warnings int, plan text, plan_until timestamptz, is_test boolean,
               shadow_banned boolean, deleted_at timestamptz, boosted_until timestamptz,
               reports_against bigint, likes_sent bigint, likes_received bigint,
               matches bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select u.id, u.email::text, u.phone::text, u.created_at, u.last_sign_in_at,
         coalesce(u.raw_app_meta_data->>'provider', ''),
         coalesce(p.name, ''), coalesce(extract(year from age(p.birthday))::int, 0),
         p.birthday, coalesce(p.gender, ''), coalesce(p.interested_in, ''),
         coalesce(p.city, ''), coalesce(p.job, ''), coalesce(p.bio, ''),
         coalesce(p.looking_for, ''), p.height_cm, coalesce(p.languages, '{}'),
         coalesce(p.interests, '{}'), coalesce(p.prompt_label, ''),
         coalesce(p.prompt_answer, ''), coalesce(p.photos, '{}'),
         coalesce(p.onboarded, false), coalesce(p.verified, false),
         coalesce(p.blocked, false), coalesce(p.blocked_reason, ''), p.suspended_until,
         coalesce(p.warnings, 0), coalesce(p.plan, ''), p.plan_until,
         coalesce(p.is_test, false), coalesce(p.shadow_banned, false), p.deleted_at,
         p.boosted_until,
         (select count(*) from public.reports r where r.reported = u.id),
         (select count(*) from public.likes l where l.from_user = u.id),
         (select count(*) from public.likes l where l.to_user = u.id),
         (select count(*) from public.matches m where u.id in (m.user_a, m.user_b))
  from auth.users u
  left join public.profiles p on p.id = u.id
  where not coalesce(p.is_bot, false)
  order by u.created_at desc;
end $$;

revoke all on function public.admin_edit_profile(uuid, jsonb) from public, anon;
revoke all on function public.admin_purge_member(uuid) from public, anon;
revoke all on function public.admin_set_contact(uuid, text, text) from public, anon;
revoke all on function public.admin_member_security(uuid) from public, anon;
revoke all on function public.admin_view_as(uuid) from public, anon;
revoke all on function public.admin_export_member(uuid) from public, anon;
revoke all on function public.admin_members() from public, anon;
revoke all on function public.record_login() from public, anon, authenticated;
grant execute on function public.admin_edit_profile(uuid, jsonb) to authenticated;
grant execute on function public.admin_purge_member(uuid) to authenticated;
grant execute on function public.admin_set_contact(uuid, text, text) to authenticated;
grant execute on function public.admin_member_security(uuid) to authenticated;
grant execute on function public.admin_view_as(uuid) to authenticated;
grant execute on function public.admin_export_member(uuid) to authenticated;
grant execute on function public.admin_members() to authenticated;

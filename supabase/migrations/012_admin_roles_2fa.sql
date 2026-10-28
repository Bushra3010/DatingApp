-- Everlane admin roles and two-factor sign-in.
--
-- Every admin has a role, and each role has a fixed set of permissions,
-- checked in the database by every admin function and policy. Admin access
-- also needs a session verified with an authenticator app (aal2): a stolen
-- password alone opens nothing.

alter table public.admins
  add column if not exists role text not null default 'super_admin'
    check (role in ('super_admin', 'moderator', 'support', 'finance', 'analyst')),
  add column if not exists added_by uuid;

-- What each role may do. Super admins may do everything.
create or replace function public.role_permissions(r text)
returns text[] language sql immutable as $$
  select case r
    when 'super_admin' then array['stats', 'members', 'edit', 'moderate', 'billing', 'purge',
                                  'export', 'bots', 'content', 'audit', 'team']
    when 'moderator' then array['stats', 'members', 'edit', 'moderate', 'audit']
    when 'support' then array['stats', 'members', 'edit', 'export']
    when 'finance' then array['stats', 'members', 'billing']
    when 'analyst' then array['stats', 'members']
    else array[]::text[]
  end
$$;

-- Whether this session passed two-factor sign-in.
create or replace function public.mfa_verified()
returns boolean language sql stable as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
$$;

-- Any admin role, signed in with two factors. Member-facing triggers use
-- this to let admins change moderation fields.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.mfa_verified()
     and exists (select 1 from public.admins where user_id = auth.uid())
$$;

create or replace function public.admin_can(perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.mfa_verified()
     and exists (select 1 from public.admins
                 where user_id = auth.uid() and perm = any (public.role_permissions(role)))
$$;

create or replace function public.require_admin(perm text)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.admin_can(perm) then raise exception 'not allowed'; end if;
end $$;

-- The panel asks this first: it works before two-factor sign-in, so the
-- panel knows whether to ask for a code, and only describes the caller.
create or replace function public.admin_status()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'admin', a.user_id is not null,
    'role', a.role,
    'mfa', public.mfa_verified(),
    'permissions', case when a.user_id is not null and public.mfa_verified()
                        then to_jsonb(public.role_permissions(a.role)) else '[]'::jsonb end)
  from (select 1) one
  left join public.admins a on a.user_id = auth.uid()
$$;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.admin_can(text) to authenticated;
grant execute on function public.admin_status() to authenticated;
revoke all on function public.require_admin(text) from public, anon;
grant execute on function public.require_admin(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Team: who the admins are, their roles and 2FA status.
-- ---------------------------------------------------------------------------
create or replace function public.admin_team()
returns table (user_id uuid, email text, role text, added_at timestamptz,
               last_sign_in_at timestamptz, has_2fa boolean, is_me boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('team');
  return query
  select a.user_id, coalesce(u.email, u.phone, '')::text, a.role, a.created_at, u.last_sign_in_at,
         exists (select 1 from auth.mfa_factors f where f.user_id = a.user_id and f.status = 'verified'),
         a.user_id = auth.uid()
  from public.admins a join auth.users u on u.id = a.user_id
  order by a.created_at;
end $$;

-- The person signs up first (app or admin page); then they're added by email.
create or replace function public.admin_add_admin(person_email text, new_role text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  person uuid;
begin
  perform public.require_admin('team');
  if public.role_permissions(new_role) = array[]::text[] then raise exception 'unknown role'; end if;
  select id into person from auth.users where email = lower(trim(person_email));
  if person is null then
    raise exception 'no account uses that email; ask them to sign up first';
  end if;
  if exists (select 1 from public.profiles where id = person and is_bot) then
    raise exception 'bots can''t be admins';
  end if;
  insert into public.admins (user_id, role, added_by) values (person, new_role, auth.uid())
  on conflict (user_id) do update set role = excluded.role;
  perform public.log_admin('admin_add', person, jsonb_build_object('role', new_role, 'email', lower(trim(person_email))));
  return person;
end $$;

-- There's always at least one super admin left.
create or replace function public.keep_a_super_admin(leaving uuid)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.admins where role = 'super_admin' and user_id <> leaving) then
    raise exception 'keep at least one super admin';
  end if;
end $$;
revoke all on function public.keep_a_super_admin(uuid) from public, anon, authenticated;

create or replace function public.admin_set_role(person uuid, new_role text)
returns void language plpgsql security definer set search_path = public as $$
declare
  old_role text;
begin
  perform public.require_admin('team');
  if public.role_permissions(new_role) = array[]::text[] then raise exception 'unknown role'; end if;
  select role into old_role from public.admins where user_id = person;
  if old_role is null then raise exception 'not an admin'; end if;
  if old_role = 'super_admin' and new_role <> 'super_admin' then perform public.keep_a_super_admin(person); end if;
  update public.admins set role = new_role where user_id = person;
  perform public.log_admin('admin_role', person, jsonb_build_object('from', old_role, 'to', new_role));
end $$;

create or replace function public.admin_remove_admin(person uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  old_role text;
begin
  perform public.require_admin('team');
  select role into old_role from public.admins where user_id = person;
  if old_role is null then raise exception 'not an admin'; end if;
  if old_role = 'super_admin' then perform public.keep_a_super_admin(person); end if;
  delete from public.admins where user_id = person;
  perform public.log_admin('admin_remove', person, jsonb_build_object('role', old_role));
end $$;

-- For an admin who lost their phone: they set up 2FA again at next sign-in.
create or replace function public.admin_reset_2fa(person uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('team');
  if person = auth.uid() then raise exception 'another super admin has to reset your 2FA'; end if;
  if not exists (select 1 from public.admins where user_id = person) then raise exception 'not an admin'; end if;
  delete from auth.mfa_factors where user_id = person;
  delete from auth.sessions where user_id = person;
  perform public.log_admin('admin_reset_2fa', person, '{}');
end $$;

revoke all on function public.admin_team() from public, anon;
revoke all on function public.admin_add_admin(text, text) from public, anon;
revoke all on function public.admin_set_role(uuid, text) from public, anon;
revoke all on function public.admin_remove_admin(uuid) from public, anon;
revoke all on function public.admin_reset_2fa(uuid) from public, anon;
grant execute on function public.admin_team() to authenticated;
grant execute on function public.admin_add_admin(text, text) to authenticated;
grant execute on function public.admin_set_role(uuid, text) to authenticated;
grant execute on function public.admin_remove_admin(uuid) to authenticated;
grant execute on function public.admin_reset_2fa(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Policies: each admin write needs the matching permission.
-- ---------------------------------------------------------------------------
drop policy if exists "Admins read the audit log" on public.admin_audit;
create policy "Admins read the audit log" on public.admin_audit
  for select to authenticated using (public.admin_can('audit'));
drop policy if exists "Admins manage options" on public.app_options;
create policy "Admins manage options" on public.app_options
  for all to authenticated using (public.admin_can('content')) with check (public.admin_can('content'));
drop policy if exists "Admins manage questions" on public.quiz_questions;
create policy "Admins manage questions" on public.quiz_questions
  for all to authenticated using (public.admin_can('content')) with check (public.admin_can('content'));
drop policy if exists "Admins manage banned words" on public.banned_words;
create policy "Admins manage banned words" on public.banned_words
  for all to authenticated using (public.admin_can('moderate')) with check (public.admin_can('moderate'));

drop policy if exists "Admins upload any photo" on storage.objects;
create policy "Admins upload any photo" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (public.admin_can('edit') or public.admin_can('bots')));
drop policy if exists "Admins update any photo" on storage.objects;
create policy "Admins update any photo" on storage.objects
  for update to authenticated
  using (bucket_id = 'photos' and (public.admin_can('edit') or public.admin_can('bots')));
drop policy if exists "Admins delete any photo" on storage.objects;
create policy "Admins delete any photo" on storage.objects
  for delete to authenticated
  using (bucket_id in ('photos', 'voice')
         and (public.admin_can('moderate') or public.admin_can('edit') or public.admin_can('bots')
              or public.admin_can('purge')));
drop policy if exists "Admins read verification selfies" on storage.objects;
create policy "Admins read verification selfies" on storage.objects
  for select to authenticated using (bucket_id = 'verifications' and public.admin_can('moderate'));
drop policy if exists "Admins delete verification selfies" on storage.objects;
create policy "Admins delete verification selfies" on storage.objects
  for delete to authenticated
  using (bucket_id = 'verifications' and (public.admin_can('moderate') or public.admin_can('purge')));
-- "Admins read any photo" (any role) stays: storage needs it to delete.

-- ---------------------------------------------------------------------------
-- Admin functions, each now checking its permission.
-- ---------------------------------------------------------------------------

-- admin_audit_log: audit
CREATE OR REPLACE FUNCTION public.admin_audit_log(max_rows integer DEFAULT 200)
 RETURNS TABLE(id bigint, created_at timestamp with time zone, admin_email text, action text, target uuid, target_name text, details jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('audit');
  return query
  select a.id, a.created_at, coalesce(u.email::text, a.admin_id::text), a.action,
         a.target, coalesce(p.name, ''), a.details
  from public.admin_audit a
  left join auth.users u on u.id = a.admin_id
  left join public.profiles p on p.id = a.target
  order by a.created_at desc
  limit least(max_rows, 1000);
end $function$;

-- admin_bots: bots
CREATE OR REPLACE FUNCTION public.admin_bots()
 RETURNS SETOF profiles
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('bots');
  return query select * from public.profiles where is_bot order by updated_at desc;
end $function$;

-- admin_delete_bot: bots
CREATE OR REPLACE FUNCTION public.admin_delete_bot(bot uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  bot_name text;
begin
  perform public.require_admin('bots');
  select name into bot_name from public.profiles where id = bot and is_bot;
  if not found then raise exception 'not a bot'; end if;
  delete from auth.users where id = bot;
  perform public.log_admin('bot_delete', bot, jsonb_build_object('name', bot_name));
end $function$;

-- admin_edit_profile: edit
CREATE OR REPLACE FUNCTION public.admin_edit_profile(member uuid, data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  before public.profiles;
  changed text[];
begin
  perform public.require_admin('edit');
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
end $function$;

-- admin_export_member: export
CREATE OR REPLACE FUNCTION public.admin_export_member(member uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  doc jsonb;
begin
  perform public.require_admin('export');
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
end $function$;

-- admin_member_security: members
CREATE OR REPLACE FUNCTION public.admin_member_security(member uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('members');
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
end $function$;

-- admin_members: members
CREATE OR REPLACE FUNCTION public.admin_members()
 RETURNS TABLE(id uuid, email text, phone text, joined_at timestamp with time zone, last_sign_in_at timestamp with time zone, provider text, name text, age integer, birthday date, gender text, interested_in text, city text, job text, bio text, looking_for text, height_cm integer, languages text[], interests text[], prompt_label text, prompt_answer text, photos text[], onboarded boolean, verified boolean, blocked boolean, blocked_reason text, suspended_until timestamp with time zone, warnings integer, plan text, plan_until timestamp with time zone, is_test boolean, shadow_banned boolean, deleted_at timestamp with time zone, boosted_until timestamp with time zone, reports_against bigint, likes_sent bigint, likes_received bigint, matches bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('members');
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
end $function$;

-- admin_moderate: per action
CREATE OR REPLACE FUNCTION public.admin_moderate(member uuid, action text, reason text DEFAULT ''::text, days integer DEFAULT 0, value text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin(case
    when action in ('verify', 'unverify', 'warn', 'logout', 'mark_test', 'unmark_test') then 'edit'
    when action in ('set_plan', 'boost', 'unboost') then 'billing'
    else 'moderate' end);
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
end $function$;

-- admin_photo_queue: moderate
CREATE OR REPLACE FUNCTION public.admin_photo_queue()
 RETURNS TABLE(path text, user_id uuid, name text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('moderate');
  return query
  select r.path, r.user_id, coalesce(p.name, ''), r.created_at
  from public.photo_reviews r
  join public.profiles p on p.id = r.user_id
  where r.status = 'pending' and r.path = any (p.photos)
  order by r.created_at
  limit 200;
end $function$;

-- admin_purge_member: purge
CREATE OR REPLACE FUNCTION public.admin_purge_member(member uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  p public.profiles;
  files jsonb;
begin
  perform public.require_admin('purge');
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
end $function$;

-- admin_reports: moderate
CREATE OR REPLACE FUNCTION public.admin_reports(only_open boolean DEFAULT true)
 RETURNS TABLE(id bigint, reason text, details text, messages jsonb, status text, resolution text, created_at timestamp with time zone, reporter uuid, reporter_name text, reported uuid, reported_name text, reported_photos text[], reported_blocked boolean, reports_against bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('moderate');
  return query
  select r.id, r.reason, r.details, r.messages, r.status, r.resolution, r.created_at,
         r.reporter, coalesce(a.name, ''), r.reported, coalesce(b.name, ''),
         coalesce(b.photos, '{}'), coalesce(b.blocked, false),
         (select count(*) from public.reports o where o.reported = r.reported)
  from public.reports r
  left join public.profiles a on a.id = r.reporter
  left join public.profiles b on b.id = r.reported
  where not only_open or r.status = 'open'
  order by r.created_at desc;
end $function$;

-- admin_resolve_report: moderate
CREATE OR REPLACE FUNCTION public.admin_resolve_report(report bigint, outcome text, note text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('moderate');
  if outcome not in ('resolved', 'dismissed', 'open') then raise exception 'bad outcome'; end if;
  update public.reports
     set status = outcome, resolution = coalesce(note, ''),
         resolved_at = case when outcome = 'open' then null else now() end,
         resolved_by = case when outcome = 'open' then null else auth.uid() end
   where id = report;
  perform public.log_admin('report_' || outcome, null,
                           jsonb_build_object('report', report, 'note', coalesce(note, '')));
end $function$;

-- admin_review_photo: moderate
CREATE OR REPLACE FUNCTION public.admin_review_photo(photo text, approve boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  owner uuid;
begin
  perform public.require_admin('moderate');
  update public.photo_reviews
     set status = case when approve then 'approved' else 'rejected' end,
         reviewed_at = now(), reviewed_by = auth.uid()
   where path = photo
  returning user_id into owner;
  if not approve then
    update public.profiles set photos = array_remove(photos, photo) where id = owner;
  end if;
  perform public.log_admin(case when approve then 'photo_approve' else 'photo_reject' end,
                           owner, jsonb_build_object('path', photo));
end $function$;

-- admin_review_verification: moderate
CREATE OR REPLACE FUNCTION public.admin_review_verification(request bigint, approve boolean, note text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  owner uuid;
begin
  perform public.require_admin('moderate');
  update public.verification_requests
     set status = case when approve then 'approved' else 'rejected' end,
         note = case when approve then '' else coalesce(note, '') end,
         reviewed_at = now(), reviewed_by = auth.uid()
   where id = request and status = 'pending'
  returning user_id into owner;
  if owner is null then raise exception 'that request was already reviewed'; end if;
  update public.profiles set verified = approve where id = owner;
  perform public.log_admin(case when approve then 'verify' else 'verify_reject' end,
                           owner, jsonb_build_object('request', request,
                                                     'note', coalesce(note, '')));
end $function$;

-- admin_save_bot: bots
CREATE OR REPLACE FUNCTION public.admin_save_bot(bot uuid, data jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  creating boolean := bot is null;
begin
  perform public.require_admin('bots');
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
end $function$;

-- admin_set_blocked: moderate
CREATE OR REPLACE FUNCTION public.admin_set_blocked(member uuid, block boolean, reason text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('moderate');
  insert into public.profiles (id) values (member) on conflict (id) do nothing;
  update public.profiles
     set blocked = block,
         blocked_reason = case when block then coalesce(reason, '') else '' end,
         blocked_at = case when block then now() else null end
   where id = member;
  perform public.log_admin(case when block then 'ban' else 'unban' end, member,
                           jsonb_build_object('reason', coalesce(reason, '')));
end $function$;

-- admin_set_bots_live: bots
CREATE OR REPLACE FUNCTION public.admin_set_bots_live(live boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  changed int;
begin
  perform public.require_admin('bots');
  update public.profiles
     set blocked = not live,
         blocked_reason = case when live then '' else 'Bots switched off' end,
         blocked_at = case when live then null else now() end
   where is_bot and blocked = live;
  get diagnostics changed = row_count;
  perform public.log_admin(case when live then 'bots_on' else 'bots_off' end, null,
                           jsonb_build_object('count', changed));
  return changed;
end $function$;

-- admin_set_contact: edit
CREATE OR REPLACE FUNCTION public.admin_set_contact(member uuid, new_email text, new_phone text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'auth', 'public'
AS $function$
declare
  old_email text;
  old_phone text;
begin
  perform public.require_admin('edit');
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
end $function$;

-- admin_stats: stats
CREATE OR REPLACE FUNCTION public.admin_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  today timestamptz := date_trunc('day', now());
begin
  perform public.require_admin('stats');
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
end $function$;

-- admin_verification_queue: moderate
CREATE OR REPLACE FUNCTION public.admin_verification_queue()
 RETURNS TABLE(id bigint, user_id uuid, name text, photo text, frames text[], created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('moderate');
  return query
  select r.id, r.user_id, coalesce(p.name, ''), coalesce(p.photos[1], ''), r.frames,
         r.created_at
  from public.verification_requests r
  join public.profiles p on p.id = r.user_id
  where r.status = 'pending'
  order by r.created_at
  limit 200;
end $function$;

-- admin_view_as: members
CREATE OR REPLACE FUNCTION public.admin_view_as(member uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.require_admin('members');
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
end $function$;

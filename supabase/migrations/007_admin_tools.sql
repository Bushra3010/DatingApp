-- Everlane admin tools: verify / warn / suspend, manual plan changes, test
-- accounts, a report inbox, a photo review queue, banned words, daily
-- metrics and an append-only audit log of every admin action.

-- ---------------------------------------------------------------------------
-- Moderation fields on profiles. Only admins can set them (trigger below).
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists suspended_until timestamptz,
  add column if not exists warnings int not null default 0,
  add column if not exists warning text not null default '',
  add column if not exists warned_at timestamptz,
  -- Set by an admin for support/troubleshooting; '' means the member's own.
  add column if not exists plan text not null default ''
    check (plan in ('', 'free', 'plus', 'gold', 'platinum')),
  -- Test accounts only ever see and are seen by other test accounts, so
  -- internal profiles can be used to try the app without reaching members.
  add column if not exists is_test boolean not null default false;

-- Members upsert their own row, but never change moderation fields, their
-- verified badge, plan or test flag. (Verification is granted by an admin.)
create or replace function public.keep_block_admin_only()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.blocked := false; new.blocked_reason := ''; new.blocked_at := null;
      new.suspended_until := null; new.warnings := 0; new.warning := '';
      new.warned_at := null; new.plan := ''; new.is_test := false;
      new.verified := false;
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
    end if;
  end if;
  return new;
end $$;

-- Blocked or currently suspended members can't like or message anyone.
create or replace function public.not_blocked()
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.profiles
                     where id = auth.uid()
                       and (blocked or coalesce(suspended_until > now(), false)))
$$;

-- Whether [p] can appear to the signed-in member: not blocked or suspended,
-- and on the same side of the test / real divide.
create or replace function public.visible_to_me(p public.profiles)
returns boolean language sql stable security definer set search_path = public as $$
  select not p.blocked
     and coalesce(p.suspended_until <= now(), true)
     and p.is_test = coalesce((select is_test from public.profiles where id = auth.uid()), false)
$$;

-- ---------------------------------------------------------------------------
-- Audit log: append-only. Written only by the admin functions below.
-- ---------------------------------------------------------------------------
create table if not exists public.admin_audit (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  target uuid,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
alter table public.admin_audit enable row level security;
drop policy if exists "Admins read the audit log" on public.admin_audit;
create policy "Admins read the audit log" on public.admin_audit
  for select to authenticated using (public.is_admin());
-- No insert, update or delete policies, and a trigger as a second lock.
create or replace function public.audit_is_append_only()
returns trigger language plpgsql as $$
begin
  raise exception 'the audit log is append-only';
end $$;
drop trigger if exists admin_audit_append_only on public.admin_audit;
create trigger admin_audit_append_only before update or delete on public.admin_audit
  for each row execute function public.audit_is_append_only();

create or replace function public.log_admin(action text, target uuid, details jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.admin_audit (admin_id, action, target, details)
  values (auth.uid(), action, target, coalesce(details, '{}'))
$$;
revoke all on function public.log_admin(text, uuid, jsonb) from public, anon, authenticated;

-- Blocking now goes in the audit log too.
create or replace function public.admin_set_blocked(member uuid, block boolean, reason text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  insert into public.profiles (id) values (member) on conflict (id) do nothing;
  update public.profiles
     set blocked = block,
         blocked_reason = case when block then coalesce(reason, '') else '' end,
         blocked_at = case when block then now() else null end
   where id = member;
  perform public.log_admin(case when block then 'ban' else 'unban' end, member,
                           jsonb_build_object('reason', coalesce(reason, '')));
end $$;

-- One entry point for the member actions in the panel.
--   verify / unverify, warn (reason = message), suspend (days),
--   unsuspend, set_plan (value = '' | free | plus | gold | platinum),
--   mark_test / unmark_test
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
    when 'set_plan' then update public.profiles set plan = coalesce(value, '') where id = member;
    when 'mark_test' then update public.profiles set is_test = true where id = member;
    when 'unmark_test' then update public.profiles set is_test = false where id = member;
    else raise exception 'unknown action %', action;
  end case;
  perform public.log_admin(action, member, jsonb_build_object(
    'reason', coalesce(reason, ''), 'days', days, 'value', coalesce(value, '')));
end $$;

-- Members see a warning once, then clear it.
create or replace function public.acknowledge_warning()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('everlane.ack_warning', 'on', true);
  update public.profiles set warning = '' where id = auth.uid();
  perform set_config('everlane.ack_warning', 'off', true);
end $$;

-- ---------------------------------------------------------------------------
-- Reports. Submitting one keeps a copy of the last five messages between
-- the two members, since blocking afterwards unmatches and deletes the chat.
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  reporter uuid not null references public.profiles (id) on delete cascade,
  reported uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 120),
  details text not null default '' check (char_length(details) <= 1000),
  messages jsonb not null default '[]',
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolution text not null default '',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid,
  check (reporter <> reported)
);
create index if not exists reports_status_idx on public.reports (status, created_at desc);
alter table public.reports enable row level security;
-- No member policies: reports go in through submit_report() only.

create or replace function public.submit_report(member uuid, reason text, details text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  recent jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'sender', case when x.sender = auth.uid() then 'reporter' else 'reported' end,
           'body', x.body, 'at', x.created_at) order by x.created_at), '[]')
    into recent
    from (select msg.sender, msg.body, msg.created_at
            from public.messages msg
            join public.matches m on m.id = msg.match_id
           where (m.user_a, m.user_b) in ((auth.uid(), member), (member, auth.uid()))
           order by msg.created_at desc
           limit 5) x;
  insert into public.reports (reporter, reported, reason, details, messages)
  values (auth.uid(), member, reason, coalesce(details, ''), recent);
end $$;

create or replace function public.admin_reports(only_open boolean default true)
returns table (id bigint, reason text, details text, messages jsonb, status text,
               resolution text, created_at timestamptz, reporter uuid,
               reporter_name text, reported uuid, reported_name text,
               reported_photos text[], reported_blocked boolean,
               reports_against bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
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
end $$;

create or replace function public.admin_resolve_report(report bigint, outcome text, note text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  if outcome not in ('resolved', 'dismissed', 'open') then raise exception 'bad outcome'; end if;
  update public.reports
     set status = outcome, resolution = coalesce(note, ''),
         resolved_at = case when outcome = 'open' then null else now() end,
         resolved_by = case when outcome = 'open' then null else auth.uid() end
   where id = report;
  perform public.log_admin('report_' || outcome, null,
                           jsonb_build_object('report', report, 'note', coalesce(note, '')));
end $$;

-- ---------------------------------------------------------------------------
-- Photo review queue. Every newly added profile photo lands here as pending.
-- ---------------------------------------------------------------------------
create table if not exists public.photo_reviews (
  path text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid
);
create index if not exists photo_reviews_pending_idx on public.photo_reviews (status, created_at);
alter table public.photo_reviews enable row level security;

create or replace function public.queue_new_photos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.photo_reviews (path, user_id)
  select p, new.id from unnest(new.photos) p
  on conflict (path) do nothing;
  return new;
end $$;
drop trigger if exists profiles_queue_photos on public.profiles;
create trigger profiles_queue_photos after insert or update of photos on public.profiles
  for each row execute function public.queue_new_photos();

create or replace function public.admin_photo_queue()
returns table (path text, user_id uuid, name text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select r.path, r.user_id, coalesce(p.name, ''), r.created_at
  from public.photo_reviews r
  join public.profiles p on p.id = r.user_id
  where r.status = 'pending' and r.path = any (p.photos)
  order by r.created_at
  limit 200;
end $$;

-- Rejecting takes the photo off the profile; the panel then deletes the file.
create or replace function public.admin_review_photo(photo text, approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
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
end $$;

drop policy if exists "Admins delete any photo" on storage.objects;
create policy "Admins delete any photo" on storage.objects
  for delete to authenticated
  using (bucket_id in ('photos', 'voice') and public.is_admin());

-- ---------------------------------------------------------------------------
-- Banned words: blocked from messages and from profile text.
-- ---------------------------------------------------------------------------
create table if not exists public.banned_words (
  word text primary key check (char_length(trim(word)) between 2 and 100),
  created_at timestamptz not null default now()
);
alter table public.banned_words enable row level security;
drop policy if exists "Admins manage banned words" on public.banned_words;
create policy "Admins manage banned words" on public.banned_words
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.has_banned_word(t text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.banned_words w
                 where position(lower(w.word) in lower(coalesce(t, ''))) > 0)
$$;

create or replace function public.reject_banned_message()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.has_banned_word(new.body) then
    raise exception 'banned_word' using hint = 'This message contains words that aren''t allowed.';
  end if;
  return new;
end $$;
drop trigger if exists messages_banned_words on public.messages;
create trigger messages_banned_words before insert on public.messages
  for each row execute function public.reject_banned_message();

create or replace function public.reject_banned_profile_text()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() and public.has_banned_word(
       concat_ws(' ', new.name, new.job, new.bio, new.prompt_answer)) then
    raise exception 'banned_word' using hint = 'Your profile contains words that aren''t allowed.';
  end if;
  return new;
end $$;
drop trigger if exists profiles_banned_words on public.profiles;
create trigger profiles_banned_words before insert or update of name, job, bio, prompt_answer
  on public.profiles for each row execute function public.reject_banned_profile_text();

-- ---------------------------------------------------------------------------
-- Stats and the members list gain the new fields.
-- ---------------------------------------------------------------------------
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  today timestamptz := date_trunc('day', now());
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'accounts', (select count(*) from auth.users),
    'profiles', (select count(*) from public.profiles where not is_test),
    'onboarded', (select count(*) from public.profiles where onboarded and not is_test),
    'blocked', (select count(*) from public.profiles where blocked),
    'suspended', (select count(*) from public.profiles where suspended_until > now()),
    'test_accounts', (select count(*) from public.profiles where is_test),
    'signups_today', (select count(*) from auth.users where created_at >= today),
    'signups_7d', (select count(*) from auth.users where created_at >= now() - interval '7 days'),
    -- Active today: signed in, saved their profile, liked, passed or messaged.
    'dau', (select count(distinct u) from (
              select id u from auth.users where last_sign_in_at >= today
              union select id from public.profiles where updated_at >= today
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

drop function if exists public.admin_members();
create function public.admin_members()
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
  order by u.created_at desc;
end $$;

create or replace function public.admin_audit_log(max_rows int default 200)
returns table (id bigint, created_at timestamptz, admin_email text, action text,
               target uuid, target_name text, details jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select a.id, a.created_at, coalesce(u.email::text, a.admin_id::text), a.action,
         a.target, coalesce(p.name, ''), a.details
  from public.admin_audit a
  left join auth.users u on u.id = a.admin_id
  left join public.profiles p on p.id = a.target
  order by a.created_at desc
  limit least(max_rows, 1000);
end $$;

-- ---------------------------------------------------------------------------
-- Member cards respect suspensions and the test / real divide.
-- ---------------------------------------------------------------------------
drop function if exists public.discover_members(int);
drop function if exists public.likes_received();
drop function if exists public.my_matches();

create function public.discover_members(max_results int default 50)
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
  order by p.updated_at desc
  limit max_results
$$;

create function public.likes_received()
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int,
               target text, comment text, liked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds,
         l.target, l.comment, l.created_at
  from public.likes l
  join public.profiles p on p.id = l.from_user
  where l.to_user = auth.uid() and public.visible_to_me(p)
    and not exists (select 1 from public.likes back
                    where back.from_user = auth.uid() and back.to_user = l.from_user)
    and not exists (select 1 from public.passes s
                    where s.from_user = auth.uid() and s.to_user = l.from_user)
  order by l.created_at desc
$$;

create function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language sql stable security definer set search_path = public as $$
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
  order by m.created_at desc
$$;

-- ---------------------------------------------------------------------------
-- Grants.
-- ---------------------------------------------------------------------------
revoke all on function public.discover_members(int) from public, anon;
revoke all on function public.likes_received() from public, anon;
revoke all on function public.my_matches() from public, anon;
revoke all on function public.visible_to_me(public.profiles) from public, anon;
revoke all on function public.admin_moderate(uuid, text, text, int, text) from public, anon;
revoke all on function public.acknowledge_warning() from public, anon;
revoke all on function public.submit_report(uuid, text, text) from public, anon;
revoke all on function public.admin_reports(boolean) from public, anon;
revoke all on function public.admin_resolve_report(bigint, text, text) from public, anon;
revoke all on function public.admin_photo_queue() from public, anon;
revoke all on function public.admin_review_photo(text, boolean) from public, anon;
revoke all on function public.has_banned_word(text) from public, anon;
revoke all on function public.admin_stats() from public, anon;
revoke all on function public.admin_members() from public, anon;
revoke all on function public.admin_audit_log(int) from public, anon;
grant execute on function public.discover_members(int) to authenticated;
grant execute on function public.likes_received() to authenticated;
grant execute on function public.my_matches() to authenticated;
grant execute on function public.visible_to_me(public.profiles) to authenticated;
grant execute on function public.admin_moderate(uuid, text, text, int, text) to authenticated;
grant execute on function public.acknowledge_warning() to authenticated;
grant execute on function public.submit_report(uuid, text, text) to authenticated;
grant execute on function public.admin_reports(boolean) to authenticated;
grant execute on function public.admin_resolve_report(bigint, text, text) to authenticated;
grant execute on function public.admin_photo_queue() to authenticated;
grant execute on function public.admin_review_photo(text, boolean) to authenticated;
grant execute on function public.has_banned_word(text) to authenticated;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.admin_members() to authenticated;
grant execute on function public.admin_audit_log(int) to authenticated;

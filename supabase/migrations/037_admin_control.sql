-- Admin panel, all real: everything the panel's former sample pages showed
-- now reads and writes the database, and the app follows what admins set.
--
--  * app_config: maintenance mode, minimum app version, feature flags,
--    onboarding rules, auto-moderation, bot phase-out, matching weights,
--    referral reward, minimum age. The app reads app_settings().
--  * announcements: banners / notices shown in the app (also "broadcast").
--  * support_tickets + ticket_messages: Help in the app, Tickets / Live chat /
--    Appeals in the panel. faq: the Help center.
--  * data_requests: members ask for an export or deletion (DPDP / GDPR).
--  * banned_identities: emails, phone numbers and domains that can't use
--    the app.
--  * Moderation views over real data: flagged messages, suspected fakes,
--    possible minors, shared IPs (multi-accounts), auto-moderation.
--  * Referrals, consent records, retention cohorts, location status, bot
--    activity and phase-out, database and job health.

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;

insert into public.app_config (key, value) values
  ('maintenance', '{"on": false, "message": "Everlane is getting an update. We’ll be back shortly."}'),
  ('min_version', '{"web": "", "android": "", "ios": "", "message": "Please update Everlane to keep going."}'),
  ('flags', '{"hangouts": true, "likes_you": true, "boost": true, "sparks": true, "rewind": true, "quiz": true, "voice_prompts": true, "crossed_paths": true, "introductions": true, "selfie_verification": true, "referrals": true}'),
  ('onboarding', '{"require_photo": true, "min_photos": 1, "require_city": false, "require_interests": false, "require_bio": false}'),
  ('auto_mod', '{"enabled": true, "reports_to_suspend": 3, "window_hours": 24, "suspend_days": 7, "auto_hide_links": true}'),
  ('phase_out', '{"enabled": false, "real_members_per_city": 50}'),
  ('algo', '{"distance": 40, "recent": 20, "verified": 15, "shared_interests": 15, "complete_profile": 10}'),
  ('referral', '{"enabled": true, "reward_days": 7, "reward_plan": "plus"}'),
  ('age', '{"min_age": 18}')
on conflict (key) do nothing;

-- What the app reads at start-up (no secrets here).
create or replace function public.app_settings()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}') from public.app_config
   where key in ('maintenance', 'min_version', 'flags', 'onboarding', 'age', 'referral')
$$;
grant execute on function public.app_settings() to anon, authenticated;

create or replace function public.admin_config()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return (select coalesce(jsonb_object_agg(key, value || jsonb_build_object('_updated_at', updated_at)), '{}')
            from public.app_config);
end $$;

-- Merges [value] into the key's object. Content and moderation settings
-- need 'content' / 'moderate'; the rest need 'team' (super admin).
create or replace function public.admin_set_config(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin(case
    when p_key in ('flags', 'onboarding', 'age', 'referral') then 'content'
    when p_key in ('auto_mod') then 'moderate'
    when p_key in ('phase_out', 'algo') then 'bots'
    else 'team' end);
  if jsonb_typeof(p_value) <> 'object' then raise exception 'value must be an object'; end if;
  insert into public.app_config (key, value, updated_at, updated_by)
  values (p_key, p_value, now(), auth.uid())
  on conflict (key) do update
    set value = public.app_config.value || excluded.value, updated_at = now(), updated_by = auth.uid();
  perform public.log_admin('config', null, jsonb_build_object('key', p_key, 'value', p_value));
end $$;

-- ---------------------------------------------------------------------------
-- Announcements (banners / notices / broadcasts)
-- ---------------------------------------------------------------------------
create table if not exists public.announcements (
  id bigint generated always as identity primary key,
  kind text not null default 'banner' check (kind in ('banner', 'notice')),
  title text not null check (char_length(title) between 1 and 80),
  body text not null default '' check (char_length(body) <= 400),
  cta_label text not null default '',
  cta_url text not null default '',
  audience text not null default 'all' check (audience in ('all', 'free', 'premium', 'new', 'city')),
  city text not null default '',
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid
);
alter table public.announcements enable row level security;
revoke all on public.announcements from anon, authenticated;

create or replace function public.my_announcements()
returns setof public.announcements language sql stable security definer set search_path = public as $$
  select a.* from public.announcements a
  left join public.profiles me on me.id = auth.uid()
  left join auth.users u on u.id = auth.uid()
   where a.active and a.starts_at <= now() and (a.ends_at is null or a.ends_at > now())
     and (a.audience = 'all'
          or (a.audience = 'free' and coalesce(me.plan, '') in ('', 'free'))
          or (a.audience = 'premium' and me.plan in ('plus', 'gold', 'platinum') and me.plan_until > now())
          or (a.audience = 'new' and u.created_at > now() - interval '7 days')
          or (a.audience = 'city' and lower(split_part(me.city, ',', 1)) = lower(trim(a.city))))
   order by a.created_at desc limit 5
$$;
grant execute on function public.my_announcements() to anon, authenticated;

create or replace function public.admin_announcements()
returns setof public.announcements language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('content');
  return query select * from public.announcements order by created_at desc limit 200;
end $$;

-- item: {id?, kind, title, body, cta_label, cta_url, audience, city, active, starts_at, ends_at}
create or replace function public.admin_save_announcement(item jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  made bigint := nullif(item->>'id', '')::bigint;
begin
  perform public.require_admin('content');
  if made is null then
    insert into public.announcements (kind, title, body, cta_label, cta_url, audience, city, active, starts_at, ends_at, created_by)
    values (coalesce(item->>'kind', 'banner'), trim(item->>'title'), coalesce(item->>'body', ''),
            coalesce(item->>'cta_label', ''), coalesce(item->>'cta_url', ''), coalesce(item->>'audience', 'all'),
            coalesce(item->>'city', ''), coalesce((item->>'active')::boolean, true),
            coalesce(nullif(item->>'starts_at', '')::timestamptz, now()), nullif(item->>'ends_at', '')::timestamptz,
            auth.uid())
    returning id into made;
  else
    update public.announcements set
      kind = coalesce(item->>'kind', kind), title = coalesce(trim(item->>'title'), title),
      body = coalesce(item->>'body', body), cta_label = coalesce(item->>'cta_label', cta_label),
      cta_url = coalesce(item->>'cta_url', cta_url), audience = coalesce(item->>'audience', audience),
      city = coalesce(item->>'city', city), active = coalesce((item->>'active')::boolean, active),
      starts_at = coalesce(nullif(item->>'starts_at', '')::timestamptz, starts_at),
      ends_at = case when item ? 'ends_at' then nullif(item->>'ends_at', '')::timestamptz else ends_at end
    where id = made;
  end if;
  perform public.log_admin('announcement', null, jsonb_build_object('id', made, 'title', item->>'title'));
  return made;
end $$;

create or replace function public.admin_delete_announcement(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('content');
  delete from public.announcements where id = p_id;
  perform public.log_admin('announcement_delete', null, jsonb_build_object('id', p_id));
end $$;

-- ---------------------------------------------------------------------------
-- Support: tickets (also live chat and appeals) and the help center
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  subject text not null check (char_length(subject) between 1 and 120),
  category text not null default 'general'
    check (category in ('general', 'account', 'billing', 'safety', 'bug', 'appeal', 'other')),
  status text not null default 'open' check (status in ('open', 'pending', 'resolved')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high')),
  assigned_to uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  member_seen_at timestamptz,
  admin_seen_at timestamptz
);
create table if not exists public.ticket_messages (
  id bigint generated always as identity primary key,
  ticket_id bigint not null references public.support_tickets (id) on delete cascade,
  sender uuid,
  from_admin boolean not null default false,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists ticket_messages_ticket on public.ticket_messages (ticket_id, created_at);
alter table public.support_tickets enable row level security;
alter table public.ticket_messages enable row level security;
revoke all on public.support_tickets, public.ticket_messages from anon, authenticated;

create or replace function public.create_ticket(p_subject text, p_category text, p_body text)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  made bigint;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if (select count(*) from public.support_tickets where user_id = auth.uid()
        and created_at > now() - interval '1 day') >= 5 then
    raise exception 'too many requests today, please wait for a reply';
  end if;
  insert into public.support_tickets (user_id, subject, category, priority, member_seen_at)
  values (auth.uid(), trim(p_subject), coalesce(nullif(p_category, ''), 'general'),
          case when p_category in ('safety', 'appeal') then 'high' else 'normal' end, now())
  returning id into made;
  insert into public.ticket_messages (ticket_id, sender, body) values (made, auth.uid(), trim(p_body));
  return made;
end $$;

create or replace function public.my_tickets()
returns table (id bigint, subject text, category text, status text, updated_at timestamptz, unread int)
language sql stable security definer set search_path = public as $$
  select t.id, t.subject, t.category, t.status, t.updated_at,
         (select count(*) from public.ticket_messages m where m.ticket_id = t.id and m.from_admin
            and m.created_at > coalesce(t.member_seen_at, '-infinity'::timestamptz))::int
    from public.support_tickets t where t.user_id = auth.uid() order by t.updated_at desc
$$;

create or replace function public.ticket_thread(p_ticket bigint)
returns table (id bigint, from_admin boolean, body text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.support_tickets where id = p_ticket and user_id = auth.uid()) then
    raise exception 'not found';
  end if;
  update public.support_tickets set member_seen_at = now() where id = p_ticket;
  return query select m.id, m.from_admin, m.body, m.created_at from public.ticket_messages m
                where m.ticket_id = p_ticket order by m.created_at;
end $$;

create or replace function public.reply_ticket(p_ticket bigint, p_body text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.support_tickets where id = p_ticket and user_id = auth.uid()) then
    raise exception 'not found';
  end if;
  insert into public.ticket_messages (ticket_id, sender, body) values (p_ticket, auth.uid(), trim(p_body));
  update public.support_tickets
     set status = case when status = 'resolved' then 'open' else status end,
         updated_at = now(), member_seen_at = now()
   where id = p_ticket;
end $$;

create or replace function public.admin_tickets(p_status text default null, p_category text default null)
returns table (id bigint, user_id uuid, member_name text, member_email text, subject text, category text,
               status text, priority text, assigned_to uuid, assignee_email text, created_at timestamptz,
               updated_at timestamptz, messages int, last_body text, last_from_admin boolean, unread int,
               member_blocked boolean, member_suspended_until timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('members');
  return query
    select t.id, t.user_id, p.name, coalesce(u.email, u.phone, '')::text, t.subject, t.category, t.status,
           t.priority, t.assigned_to, coalesce(au.email, '')::text, t.created_at, t.updated_at,
           (select count(*) from public.ticket_messages m where m.ticket_id = t.id)::int,
           (select m.body from public.ticket_messages m where m.ticket_id = t.id order by m.created_at desc limit 1),
           (select m.from_admin from public.ticket_messages m where m.ticket_id = t.id order by m.created_at desc limit 1),
           (select count(*) from public.ticket_messages m where m.ticket_id = t.id and not m.from_admin
              and m.created_at > coalesce(t.admin_seen_at, '-infinity'::timestamptz))::int,
           coalesce(p.blocked, false), p.suspended_until
      from public.support_tickets t
      left join public.profiles p on p.id = t.user_id
      left join auth.users u on u.id = t.user_id
      left join auth.users au on au.id = t.assigned_to
     where (p_status is null or t.status = p_status)
       and (p_category is null or t.category = p_category)
     order by (t.status = 'open') desc, t.priority = 'high' desc, t.updated_at desc
     limit 500;
end $$;

create or replace function public.admin_ticket_thread(p_ticket bigint)
returns table (id bigint, from_admin boolean, sender_email text, body text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('members');
  update public.support_tickets set admin_seen_at = now() where id = p_ticket;
  return query select m.id, m.from_admin, coalesce(u.email, '')::text, m.body, m.created_at
                 from public.ticket_messages m left join auth.users u on u.id = m.sender
                where m.ticket_id = p_ticket order by m.created_at;
end $$;

create or replace function public.admin_reply_ticket(p_ticket bigint, p_body text, p_status text default 'pending')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('members');
  insert into public.ticket_messages (ticket_id, sender, from_admin, body) values (p_ticket, auth.uid(), true, trim(p_body));
  update public.support_tickets
     set status = coalesce(p_status, status), updated_at = now(), admin_seen_at = now(),
         assigned_to = coalesce(assigned_to, auth.uid())
   where id = p_ticket;
  perform public.log_admin('ticket_reply', (select user_id from public.support_tickets where id = p_ticket),
                           jsonb_build_object('ticket', p_ticket));
end $$;

create or replace function public.admin_update_ticket(p_ticket bigint, p_status text default null,
                                                     p_priority text default null, p_assign_me boolean default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('members');
  update public.support_tickets set
    status = coalesce(p_status, status), priority = coalesce(p_priority, priority),
    assigned_to = case when p_assign_me is null then assigned_to when p_assign_me then auth.uid() else null end,
    updated_at = now()
  where id = p_ticket;
  perform public.log_admin('ticket_update', (select user_id from public.support_tickets where id = p_ticket),
                           jsonb_build_object('ticket', p_ticket, 'status', p_status, 'priority', p_priority));
end $$;

-- Appeals: granting one lifts the suspension / block and resolves it.
create or replace function public.admin_decide_appeal(p_ticket bigint, p_grant boolean, p_note text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  member uuid;
begin
  perform public.require_admin('moderate');
  select user_id into member from public.support_tickets where id = p_ticket and category = 'appeal';
  if member is null then raise exception 'not an appeal'; end if;
  if p_grant then
    update public.profiles set suspended_until = null, blocked = false, blocked_reason = '', blocked_at = null,
                               shadow_banned = false
     where id = member;
  end if;
  insert into public.ticket_messages (ticket_id, sender, from_admin, body)
  values (p_ticket, auth.uid(), true, coalesce(nullif(trim(p_note), ''),
          case when p_grant then 'Your appeal was accepted and your account is back to normal.'
               else 'We reviewed your appeal and the decision stays.' end));
  update public.support_tickets set status = 'resolved', updated_at = now() where id = p_ticket;
  perform public.log_admin(case when p_grant then 'appeal_granted' else 'appeal_denied' end, member,
                           jsonb_build_object('ticket', p_ticket));
end $$;

create table if not exists public.faq (
  id bigint generated always as identity primary key,
  category text not null default 'General',
  question text not null check (char_length(question) between 1 and 200),
  answer text not null check (char_length(answer) between 1 and 3000),
  position int not null default 100,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.faq enable row level security;
revoke all on public.faq from anon, authenticated;
grant select on public.faq to anon, authenticated;
drop policy if exists "faq readable" on public.faq;
create policy "faq readable" on public.faq for select using (active);

insert into public.faq (category, question, answer, position)
select * from (values
  ('Safety', 'How do I get verified?', 'Open your profile, tap Get verified and take a quick live selfie. The team checks it, usually within a day, and you get the blue badge.', 1),
  ('Account', 'How do I delete my account?', 'Go to You → Preferences → Delete account. Your profile, photos, likes, matches and messages are removed.', 2),
  ('Safety', 'How do I report or block someone?', 'Open their profile, tap ••• and choose Report or Block. Reports go to our moderation team; the person isn’t told who reported them.', 3),
  ('Billing', 'How do premium plans work?', 'Plus, Gold and Platinum renew monthly until you cancel. You can see what each includes on the Membership screen.', 4),
  ('Hangouts', 'Is it safe to meet from Hangouts?', 'Meet in a public place, tell a friend where you’ll be, and leave if anything feels off. The exact venue is only shared with guests the host accepts.', 5)
) v(c, q, a, p)
where not exists (select 1 from public.faq);

create or replace function public.admin_faq()
returns setof public.faq language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('content');
  return query select * from public.faq order by position, id;
end $$;

create or replace function public.admin_save_faq(item jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  made bigint := nullif(item->>'id', '')::bigint;
begin
  perform public.require_admin('content');
  if made is null then
    insert into public.faq (category, question, answer, position, active)
    values (coalesce(nullif(item->>'category', ''), 'General'), trim(item->>'question'), trim(item->>'answer'),
            coalesce((item->>'position')::int, 100), coalesce((item->>'active')::boolean, true))
    returning id into made;
  else
    update public.faq set category = coalesce(item->>'category', category), question = coalesce(item->>'question', question),
           answer = coalesce(item->>'answer', answer), position = coalesce((item->>'position')::int, position),
           active = coalesce((item->>'active')::boolean, active), updated_at = now()
     where id = made;
  end if;
  return made;
end $$;

create or replace function public.admin_delete_faq(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('content');
  delete from public.faq where id = p_id;
end $$;

-- ---------------------------------------------------------------------------
-- Data requests (export / deletion)
-- ---------------------------------------------------------------------------
create table if not exists public.data_requests (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  email text not null default '',
  kind text not null check (kind in ('export', 'deletion', 'correction')),
  details text not null default '',
  status text not null default 'open' check (status in ('open', 'done', 'rejected')),
  note text not null default '',
  created_at timestamptz not null default now(),
  due_at timestamptz not null default now() + interval '30 days',
  completed_at timestamptz,
  completed_by uuid
);
alter table public.data_requests enable row level security;
revoke all on public.data_requests from anon, authenticated;

create or replace function public.request_my_data(p_kind text, p_details text default '')
returns bigint language plpgsql security definer set search_path = public as $$
declare
  made bigint;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.data_requests where user_id = auth.uid() and kind = p_kind and status = 'open') then
    raise exception 'you already have an open request of this kind';
  end if;
  insert into public.data_requests (user_id, email, kind, details)
  values (auth.uid(), coalesce((select email from auth.users where id = auth.uid()), ''), p_kind, coalesce(p_details, ''))
  returning id into made;
  return made;
end $$;

create or replace function public.my_data_requests()
returns table (id bigint, kind text, status text, note text, created_at timestamptz, completed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select id, kind, status, note, created_at, completed_at from public.data_requests
   where user_id = auth.uid() order by created_at desc
$$;

create or replace function public.admin_data_requests(p_status text default null)
returns table (id bigint, user_id uuid, member_name text, email text, kind text, details text, status text,
               note text, created_at timestamptz, due_at timestamptz, completed_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('export');
  return query select r.id, r.user_id, p.name, r.email, r.kind, r.details, r.status, r.note, r.created_at,
                      r.due_at, r.completed_at
                 from public.data_requests r left join public.profiles p on p.id = r.user_id
                where p_status is null or r.status = p_status
                order by (r.status = 'open') desc, r.due_at;
end $$;

create or replace function public.admin_complete_data_request(p_id bigint, p_status text, p_note text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('export');
  update public.data_requests set status = p_status, note = coalesce(p_note, ''), completed_at = now(),
         completed_by = auth.uid()
   where id = p_id;
  perform public.log_admin('data_request_' || p_status, (select user_id from public.data_requests where id = p_id),
                           jsonb_build_object('id', p_id));
end $$;

-- ---------------------------------------------------------------------------
-- Bans by identity
-- ---------------------------------------------------------------------------
create table if not exists public.banned_identities (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('email', 'phone', 'domain', 'ip')),
  value text not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid,
  unique (kind, value)
);
alter table public.banned_identities enable row level security;
revoke all on public.banned_identities from anon, authenticated;

-- The app asks this after sign-in: a banned identity is signed out.
create or replace function public.access_check()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('banned', exists (
    select 1 from public.banned_identities b, auth.users u
     where u.id = auth.uid()
       and ((b.kind = 'email' and lower(u.email) = lower(b.value))
         or (b.kind = 'domain' and lower(split_part(u.email, '@', 2)) = lower(b.value))
         or (b.kind = 'phone' and regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') = regexp_replace(b.value, '\D', '', 'g'))
         or (b.kind = 'ip' and exists (select 1 from public.login_events l where l.user_id = u.id and host(l.ip) = b.value)))))
$$;
grant execute on function public.access_check() to authenticated;

create or replace function public.admin_bans()
returns setof public.banned_identities language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('moderate');
  return query select * from public.banned_identities order by created_at desc;
end $$;

create or replace function public.admin_ban_identity(p_kind text, p_value text, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('moderate');
  insert into public.banned_identities (kind, value, reason, created_by)
  values (p_kind, lower(trim(p_value)), coalesce(p_reason, ''), auth.uid())
  on conflict (kind, value) do update set reason = excluded.reason;
  perform public.log_admin('ban_identity', null, jsonb_build_object('kind', p_kind, 'value', p_value));
end $$;

create or replace function public.admin_unban_identity(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('moderate');
  delete from public.banned_identities where id = p_id;
  perform public.log_admin('unban_identity', null, jsonb_build_object('id', p_id));
end $$;

-- ---------------------------------------------------------------------------
-- Auto-moderation: enough reports in the window suspends the member.
-- ---------------------------------------------------------------------------
create or replace function public.auto_moderate_report()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  c jsonb := (select value from public.app_config where key = 'auto_mod');
  n int;
begin
  if c is null or not coalesce((c->>'enabled')::boolean, false) then return new; end if;
  select count(distinct reporter) into n from public.reports
   where reported = new.reported
     and created_at > now() - make_interval(hours => coalesce((c->>'window_hours')::int, 24));
  if n >= coalesce((c->>'reports_to_suspend')::int, 3) then
    update public.profiles
       set suspended_until = greatest(coalesce(suspended_until, now()),
                                      now() + make_interval(days => coalesce((c->>'suspend_days')::int, 7)))
     where id = new.reported and not is_bot and not is_official;
    insert into public.admin_audit (admin_id, action, target, details)
    values (null, 'auto_suspend', new.reported, jsonb_build_object('reports', n));
  end if;
  return new;
end $$;
drop trigger if exists reports_auto_moderate on public.reports;
create trigger reports_auto_moderate after insert on public.reports
  for each row execute function public.auto_moderate_report();

-- ---------------------------------------------------------------------------
-- Moderation views over real data
-- ---------------------------------------------------------------------------
-- Messages with links, phone numbers, UPI / payment words or banned words.
create or replace function public.admin_flagged_messages(days int default 7)
returns table (id uuid, match_id uuid, sender uuid, sender_name text, receiver uuid, receiver_name text,
               body text, why text, created_at timestamptz, sender_reports int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('moderate');
  return query
    select x.id, x.match_id, x.sender, ps.name,
           case when m.user_a = x.sender then m.user_b else m.user_a end, pr.name, x.body,
           concat_ws(', ',
             case when x.body ~* '(https?://|www\.|\.com\b|\.in\b|t\.me/|bit\.ly)' then 'link' end,
             case when x.body ~ '(\+?91[ -]?)?[6-9][0-9]{9}' then 'phone number' end,
             case when x.body ~* '\m(upi|paytm|gpay|phonepe|otp|bank|account number|crypto|bitcoin|invest|send money|paise bhejo)\M' then 'money' end,
             case when x.body ~* '\m(whatsapp|telegram|snapchat|insta(gram)?)\M' then 'off-platform' end,
             case when exists (select 1 from public.banned_words w where position(lower(w.word) in lower(x.body)) > 0) then 'banned word' end),
           x.created_at,
           (select count(*) from public.reports r where r.reported = x.sender)::int
      from public.messages x
      join public.matches m on m.id = x.match_id
      left join public.profiles ps on ps.id = x.sender
      left join public.profiles pr on pr.id = case when m.user_a = x.sender then m.user_b else m.user_a end
     where x.created_at > now() - make_interval(days => greatest(days, 1))
       and not coalesce(ps.is_bot, false)
       and (x.body ~* '(https?://|www\.|\.com\b|\.in\b|t\.me/|bit\.ly)'
            or x.body ~ '(\+?91[ -]?)?[6-9][0-9]{9}'
            or x.body ~* '\m(upi|paytm|gpay|phonepe|otp|bank|account number|crypto|bitcoin|invest|send money|paise bhejo|whatsapp|telegram|snapchat|insta(gram)?)\M'
            or exists (select 1 from public.banned_words w where position(lower(w.word) in lower(x.body)) > 0))
     order by x.created_at desc
     limit 500;
end $$;

-- Accounts that look fake or spammy, with the reasons.
create or replace function public.admin_suspects()
returns table (id uuid, name text, email text, city text, created_at timestamptz, reports int, likes_24h int,
               flagged_msgs int, shared_ip_accounts int, reasons text[], blocked boolean, shadow_banned boolean,
               suspended_until timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('moderate');
  return query
    with base as (
      select p.id, p.name, coalesce(u.email, u.phone, '')::text email, p.city, u.created_at, p.bio,
             p.photos, p.verified, p.blocked, p.shadow_banned, p.suspended_until,
             (select count(*) from public.reports r where r.reported = p.id)::int reports,
             (select count(*) from public.likes l where l.from_user = p.id and l.created_at > now() - interval '24 hours')::int likes_24h,
             (select count(*) from public.messages x where x.sender = p.id
                and x.body ~* '(https?://|www\.|t\.me/|\m(upi|paytm|gpay|whatsapp|telegram|crypto|invest)\M|[6-9][0-9]{9})')::int flagged_msgs,
             (select count(distinct l2.user_id) from public.login_events l1 join public.login_events l2
                on l2.ip = l1.ip and l2.user_id <> l1.user_id where l1.user_id = p.id)::int shared_ip
        from public.profiles p join auth.users u on u.id = p.id
       where not p.is_bot and not p.is_official and p.deleted_at is null)
    select b.id, b.name, b.email, b.city, b.created_at, b.reports, b.likes_24h, b.flagged_msgs, b.shared_ip,
           array_remove(array[
             case when b.reports > 0 then b.reports || ' report(s)' end,
             case when b.likes_24h >= 100 then b.likes_24h || ' likes in 24h' end,
             case when b.flagged_msgs > 0 then b.flagged_msgs || ' message(s) with links/numbers/money' end,
             case when b.shared_ip > 0 then 'shares an IP with ' || b.shared_ip || ' account(s)' end,
             case when b.bio ~* '(https?://|www\.|whatsapp|telegram|insta|snap|[6-9][0-9]{9})' then 'contact or link in bio' end,
             case when cardinality(b.photos) = 0 then 'no photos' end
           ], null),
           b.blocked, b.shadow_banned, b.suspended_until
      from base b
     where b.reports > 0 or b.likes_24h >= 100 or b.flagged_msgs > 0 or b.shared_ip > 0
        or b.bio ~* '(https?://|www\.|whatsapp|telegram|insta|snap|[6-9][0-9]{9})'
     order by b.reports desc, b.flagged_msgs desc, b.likes_24h desc
     limit 300;
end $$;

-- Possible minors: under the minimum age by birthday, or school words.
create or replace function public.admin_underage()
returns table (id uuid, name text, email text, age int, birthday date, signal text, verified boolean,
               blocked boolean, suspended_until timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  min_age int := coalesce((select (value->>'min_age')::int from public.app_config where key = 'age'), 18);
begin
  perform public.require_admin('moderate');
  return query
    select p.id, p.name, coalesce(u.email, u.phone, '')::text,
           extract(year from age(p.birthday))::int, p.birthday,
           concat_ws(', ',
             case when p.birthday is not null and age(p.birthday) < make_interval(years => min_age) then 'under ' || min_age || ' by birthday' end,
             case when (p.bio || ' ' || p.prompt_answer || ' ' || p.job) ~* '\m(class (8|9|10|11|12)|school|12th|10th|tenth|board exams?|minor|underage|1[3-7] ?(yo|years?|yrs?)( old)?)\M' then 'mentions school or a young age' end,
             case when p.job ~* '\m(student)\M' and p.birthday is not null and age(p.birthday) < interval '19 years' then 'student, just over the limit' end),
           p.verified, p.blocked, p.suspended_until
      from public.profiles p join auth.users u on u.id = p.id
     where not p.is_bot and not p.is_official and p.deleted_at is null
       and ((p.birthday is not null and age(p.birthday) < make_interval(years => min_age))
         or (p.bio || ' ' || p.prompt_answer || ' ' || p.job) ~* '\m(class (8|9|10|11|12)|school|12th|10th|tenth|board exams?|minor|underage|1[3-7] ?(yo|years?|yrs?)( old)?)\M'
         or (p.job ~* '\m(student)\M' and p.birthday is not null and age(p.birthday) < interval '19 years'))
     order by p.birthday desc nulls last;
end $$;

-- Accounts sharing a sign-in IP.
create or replace function public.admin_shared_ips()
returns table (ip text, accounts int, members jsonb, last_seen timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('moderate');
  return query
    select host(l.ip), count(distinct l.user_id)::int,
           jsonb_agg(distinct jsonb_build_object('id', p.id, 'name', p.name, 'email', coalesce(u.email, u.phone, ''),
                                                 'blocked', p.blocked)),
           max(l.created_at)
      from public.login_events l
      join public.profiles p on p.id = l.user_id
      left join auth.users u on u.id = l.user_id
     where l.ip is not null and not p.is_bot
     group by host(l.ip)
    having count(distinct l.user_id) > 1
     order by 2 desc, 4 desc
     limit 200;
end $$;

-- Who is boosted, shadow-banned, suspended or hidden.
create or replace function public.admin_visibility()
returns table (id uuid, name text, email text, state text, until timestamptz, plan text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('members');
  return query
    select p.id, p.name, coalesce(u.email, u.phone, '')::text,
           case when p.blocked then 'Blocked' when p.shadow_banned then 'Shadow-banned'
                when p.suspended_until > now() then 'Suspended' when p.boosted_until > now() then 'Boosted'
                when not p.posted then 'Not posted' end,
           case when p.suspended_until > now() then p.suspended_until when p.boosted_until > now() then p.boosted_until end,
           p.plan
      from public.profiles p left join auth.users u on u.id = p.id
     where not p.is_bot and not p.is_official and p.deleted_at is null
       and (p.blocked or p.shadow_banned or p.suspended_until > now() or p.boosted_until > now() or not p.posted)
     order by 4, 2;
end $$;

-- ---------------------------------------------------------------------------
-- Locations: status per city, with member and bot counts.
-- ---------------------------------------------------------------------------
alter table public.geo_cities add column if not exists status text not null default 'live'
  check (status in ('live', 'waitlist', 'hidden'));

create or replace function public.admin_cities()
returns table (name text, state text, status text, members int, bots int, live_bots int, hangouts int)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('members');
  return query
    select g.name, g.state, g.status,
           (select count(*) from public.profiles p where not p.is_bot and not p.is_official and lower(split_part(p.city, ',', 1)) = lower(g.name))::int,
           (select count(*) from public.profiles p where p.is_bot and lower(split_part(p.city, ',', 1)) = lower(g.name))::int,
           (select count(*) from public.profiles p where p.is_bot and not p.blocked and lower(split_part(p.city, ',', 1)) = lower(g.name))::int,
           (select count(*) from public.hangouts h where not h.cancelled and h.starts_at > now() and lower(split_part(h.city, ',', 1)) = lower(g.name))::int
      from public.geo_cities g where g.main
     order by 4 desc, 6 desc, g.name;
end $$;

create or replace function public.admin_set_city_status(p_name text, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('content');
  update public.geo_cities set status = p_status where lower(name) = lower(p_name);
  perform public.log_admin('city_status', null, jsonb_build_object('city', p_name, 'status', p_status));
end $$;

-- ---------------------------------------------------------------------------
-- Referrals
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists referral_code text unique,
  add column if not exists referred_by uuid references public.profiles (id) on delete set null,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists terms_version text not null default '',
  add column if not exists marketing_opt_in boolean not null default false;

create or replace function public.my_referral()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  code text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select referral_code into code from public.profiles where id = auth.uid();
  if code is null then
    loop
      code := upper(substr(regexp_replace(coalesce((select name from public.profiles where id = auth.uid()), 'EVER'), '[^A-Za-z]', '', 'g') || 'EVER', 1, 4))
              || lpad((floor(random() * 10000))::int::text, 4, '0');
      exit when not exists (select 1 from public.profiles where referral_code = code);
    end loop;
    update public.profiles set referral_code = code where id = auth.uid();
  end if;
  return jsonb_build_object('code', code,
    'joined', (select count(*) from public.profiles where referred_by = auth.uid()),
    'reward_days', (select (value->>'reward_days')::int from public.app_config where key = 'referral'));
end $$;
grant execute on function public.my_referral() to authenticated;

-- A new member enters a friend's code once. The friend gets the reward.
create or replace function public.apply_referral(p_code text)
returns text language plpgsql security definer set search_path = public as $$
declare
  c jsonb := (select value from public.app_config where key = 'referral');
  friend uuid;
  days int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not coalesce((c->>'enabled')::boolean, false) then raise exception 'referrals are off right now'; end if;
  if (select referred_by from public.profiles where id = auth.uid()) is not null then
    raise exception 'you already used a code';
  end if;
  if (select u.created_at from auth.users u where u.id = auth.uid()) < now() - interval '14 days' then
    raise exception 'codes are for new members';
  end if;
  select id into friend from public.profiles where referral_code = upper(trim(p_code)) and id <> auth.uid();
  if friend is null then raise exception 'that code doesn’t exist'; end if;
  update public.profiles set referred_by = friend where id = auth.uid();
  days := coalesce((c->>'reward_days')::int, 0);
  if days > 0 then
    update public.profiles
       set plan = case when coalesce(plan, '') in ('', 'free') then coalesce(c->>'reward_plan', 'plus') else plan end,
           plan_until = greatest(coalesce(plan_until, now()), now()) + make_interval(days => days)
     where id = friend;
  end if;
  return (select name from public.profiles where id = friend);
end $$;
grant execute on function public.apply_referral(text) to authenticated;

create or replace function public.admin_referrals()
returns table (id uuid, name text, email text, code text, joined int, onboarded int, last_join timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('members');
  return query
    select p.id, p.name, coalesce(u.email, u.phone, '')::text, p.referral_code,
           count(r.id)::int, count(r.id) filter (where r.onboarded)::int, max(ru.created_at)
      from public.profiles p
      left join auth.users u on u.id = p.id
      join public.profiles r on r.referred_by = p.id
      left join auth.users ru on ru.id = r.id
     group by p.id, p.name, u.email, u.phone, p.referral_code
     order by 5 desc;
end $$;

-- ---------------------------------------------------------------------------
-- Consent
-- ---------------------------------------------------------------------------
create or replace function public.record_consent(p_terms_version text, p_marketing boolean default false)
returns void language sql security definer set search_path = public as $$
  update public.profiles set terms_accepted_at = now(), terms_version = p_terms_version,
         marketing_opt_in = coalesce(p_marketing, false)
   where id = auth.uid()
$$;
grant execute on function public.record_consent(text, boolean) to authenticated;

create or replace function public.admin_consent()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('members');
  return jsonb_build_object(
    'members', (select count(*) from public.profiles where not is_bot and not is_official and deleted_at is null),
    'terms', (select count(*) from public.profiles where not is_bot and terms_accepted_at is not null),
    'marketing', (select count(*) from public.profiles where not is_bot and marketing_opt_in),
    'location', (select count(*) from public.profiles where not is_bot and loc_lat is not null),
    'verification', (select count(distinct user_id) from public.verification_requests),
    'versions', (select coalesce(jsonb_object_agg(v, n), '{}') from
                  (select coalesce(nullif(terms_version, ''), 'not recorded') v, count(*) n from public.profiles
                    where not is_bot and not is_official group by 1) s));
end $$;

-- ---------------------------------------------------------------------------
-- Retention: of each week's sign-ups, who was active (liked, messaged or
-- signed in) in each following week.
-- ---------------------------------------------------------------------------
create or replace function public.admin_retention(weeks int default 8)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('stats');
  return (
    with members as (
      select p.id, date_trunc('week', u.created_at)::date cohort
        from public.profiles p join auth.users u on u.id = p.id
       where not p.is_bot and not p.is_official and u.created_at > now() - make_interval(weeks => greatest(weeks, 2)) ),
    activity as (
      select from_user uid, date_trunc('week', created_at)::date wk from public.likes
      union select sender, date_trunc('week', created_at)::date from public.messages
      union select user_id, date_trunc('week', created_at)::date from public.login_events ),
    grid as (
      select m.cohort, ((a.wk - m.cohort) / 7) week_no, count(distinct m.id) active
        from members m join activity a on a.uid = m.id and a.wk >= m.cohort
       group by 1, 2 )
    select coalesce(jsonb_agg(jsonb_build_object(
             'cohort', c.cohort, 'size', c.size,
             'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', g.week_no, 'active', g.active) order by g.week_no), '[]')
                         from grid g where g.cohort = c.cohort)) order by c.cohort), '[]')
      from (select cohort, count(*) size from members group by 1) c);
end $$;

-- ---------------------------------------------------------------------------
-- Bots: activity per bot, and phase-out where real members are enough.
-- ---------------------------------------------------------------------------
create or replace function public.admin_bot_activity(days int default 30)
returns table (id uuid, name text, city text, live boolean, verified boolean, likes_received int,
               matches int, messages_received int, replies_sent int, last_reply timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('bots');
  return query
    select p.id, p.name, p.city, not p.blocked, p.verified,
           (select count(*) from public.likes l where l.to_user = p.id and l.created_at > now() - make_interval(days => days))::int,
           (select count(*) from public.matches m where p.id in (m.user_a, m.user_b) and m.created_at > now() - make_interval(days => days))::int,
           (select count(*) from public.messages x join public.matches m on m.id = x.match_id
             where p.id in (m.user_a, m.user_b) and x.sender <> p.id and x.created_at > now() - make_interval(days => days))::int,
           (select count(*) from public.messages x where x.sender = p.id and x.created_at > now() - make_interval(days => days))::int,
           (select max(x.created_at) from public.messages x where x.sender = p.id)
      from public.profiles p where p.is_bot
     order by 6 desc, 5 desc
     limit 1000;
end $$;

-- Pauses the bots of every city that has enough real members. Runs daily
-- (and from the panel's "Run now").
create or replace function public.run_bot_phase_out()
returns int language plpgsql security definer set search_path = public as $$
declare
  c jsonb := (select value from public.app_config where key = 'phase_out');
  n int := 0;
begin
  if c is null or not coalesce((c->>'enabled')::boolean, false) then return 0; end if;
  update public.profiles b
     set blocked = true, blocked_reason = 'Phased out: enough real members in this city', blocked_at = now()
   where b.is_bot and not b.blocked
     and (select count(*) from public.profiles p
           where not p.is_bot and not p.is_official and p.onboarded and p.deleted_at is null
             and lower(split_part(p.city, ',', 1)) = lower(split_part(b.city, ',', 1)))
         >= coalesce((c->>'real_members_per_city')::int, 50);
  get diagnostics n = row_count;
  if n > 0 then
    insert into public.admin_audit (admin_id, action, target, details)
    values (null, 'bots_phase_out', null, jsonb_build_object('count', n));
  end if;
  return n;
end $$;

create or replace function public.admin_run_bot_phase_out()
returns int language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  return public.run_bot_phase_out();
end $$;

-- ---------------------------------------------------------------------------
-- Technical: real health numbers.
-- ---------------------------------------------------------------------------
create or replace function public.admin_tech()
returns jsonb language plpgsql stable security definer set search_path = public, cron as $$
begin
  perform public.require_admin('team');
  return jsonb_build_object(
    'database_size', pg_size_pretty(pg_database_size(current_database())),
    'tables', (select coalesce(jsonb_agg(jsonb_build_object('table', relname, 'rows', n_live_tup,
                                                            'size', pg_size_pretty(pg_total_relation_size(relid)))
                                       order by pg_total_relation_size(relid) desc), '[]')
                 from pg_stat_user_tables where schemaname = 'public'),
    'queues', jsonb_build_object(
       'bot_replies_waiting', (select count(*) from public.bot_pending_replies),
       'bot_replies_overdue', (select count(*) from public.bot_pending_replies where scheduled_at < now() - interval '5 minutes'),
       'bot_matches_waiting', (select count(*) from public.bot_pending_matches),
       'photos_to_review', (select count(*) from public.photo_reviews where status = 'pending'),
       'selfies_to_review', (select count(*) from public.verification_requests where status = 'pending'),
       'open_reports', (select count(*) from public.reports where status = 'open'),
       'open_tickets', (select count(*) from public.support_tickets where status <> 'resolved'),
       'open_data_requests', (select count(*) from public.data_requests where status = 'open')),
    'jobs', (select coalesce(jsonb_agg(jsonb_build_object('job', j.jobname, 'schedule', j.schedule, 'active', j.active,
                       'last_run', (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid),
                       'failures_24h', (select count(*) from cron.job_run_details d where d.jobid = j.jobid
                                         and d.status = 'failed' and d.start_time > now() - interval '24 hours'),
                       'runs_24h', (select count(*) from cron.job_run_details d where d.jobid = j.jobid
                                     and d.start_time > now() - interval '24 hours'))), '[]')
               from cron.job j),
    'recent_failures', (select coalesce(jsonb_agg(jsonb_build_object('job', j.jobname, 'at', d.start_time,
                                                                     'message', left(d.return_message, 300)) order by d.start_time desc), '[]')
                          from (select * from cron.job_run_details where status = 'failed' order by start_time desc limit 20) d
                          join cron.job j on j.jobid = d.jobid),
    'sign_ins_24h', (select count(*) from public.login_events where created_at > now() - interval '24 hours'),
    'messages_24h', (select count(*) from public.messages where created_at > now() - interval '24 hours'));
end $$;

-- ---------------------------------------------------------------------------
-- Daily jobs
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'bot-phase-out';
    perform cron.schedule('bot-phase-out', '30 3 * * *', 'select public.run_bot_phase_out()');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
do $$
declare
  f text;
begin
  foreach f in array array[
    'admin_config()', 'admin_set_config(text, jsonb)', 'admin_announcements()', 'admin_save_announcement(jsonb)',
    'admin_delete_announcement(bigint)', 'create_ticket(text, text, text)', 'my_tickets()', 'ticket_thread(bigint)',
    'reply_ticket(bigint, text)', 'admin_tickets(text, text)', 'admin_ticket_thread(bigint)',
    'admin_reply_ticket(bigint, text, text)', 'admin_update_ticket(bigint, text, text, boolean)',
    'admin_decide_appeal(bigint, boolean, text)', 'admin_faq()', 'admin_save_faq(jsonb)', 'admin_delete_faq(bigint)',
    'request_my_data(text, text)', 'my_data_requests()', 'admin_data_requests(text)',
    'admin_complete_data_request(bigint, text, text)', 'admin_bans()', 'admin_ban_identity(text, text, text)',
    'admin_unban_identity(bigint)', 'admin_flagged_messages(integer)', 'admin_suspects()', 'admin_underage()',
    'admin_shared_ips()', 'admin_visibility()', 'admin_cities()', 'admin_set_city_status(text, text)',
    'admin_referrals()', 'admin_consent()', 'admin_retention(integer)', 'admin_bot_activity(integer)',
    'admin_run_bot_phase_out()', 'admin_tech()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke all on function public.run_bot_phase_out() from public, anon, authenticated;
revoke all on function public.auto_moderate_report() from public, anon, authenticated;

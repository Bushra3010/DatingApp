-- 1. Discover and Hangouts use where a member actually is, not just their
--    home city: the app saves the current position (rounded to a ~1 km
--    cell, never an exact spot) and distances come from that, falling
--    back to the city centre for anyone who hasn't shared it.
-- 2. Membership plans (names, limits, perks) are editable in the panel.
-- 3. Admins can host Hangouts plans as the official Everlane profile and
--    accept or decline requests to them.

-- ---------------------------------------------------------------------------
-- 1. Live location
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists loc_lat double precision,
  add column if not exists loc_lng double precision,
  add column if not exists located_at timestamptz,
  add column if not exists is_official boolean not null default false;  -- the Everlane team's own profile

-- Rounded to the centre of a 0.01° cell (about 1 km) before it is kept.
create or replace function public.record_location(p_lat double precision, p_lng double precision)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'bad coordinates';
  end if;
  update public.profiles
     set loc_lat = (floor(p_lat / 0.01) + 0.5) * 0.01,
         loc_lng = (floor(p_lng / 0.01) + 0.5) * 0.01,
         located_at = now()
   where id = auth.uid();
end $$;

create or replace function public.clear_location()
returns void language sql security definer set search_path = public as $$
  update public.profiles set loc_lat = null, loc_lng = null, located_at = null where id = auth.uid()
$$;

-- Where a profile counts as being: the shared position when it's recent
-- (a month), otherwise the city centre.
create or replace function public.profile_point(p public.profiles, out lat double precision, out lng double precision)
language sql stable as $$
  select case when p.loc_lat is not null and p.located_at > now() - interval '30 days' then p.loc_lat else p.lat end,
         case when p.loc_lng is not null and p.located_at > now() - interval '30 days' then p.loc_lng else p.lng end
$$;

drop function if exists public.discover_members(integer, integer);
create function public.discover_members(max_results integer default 50, max_km integer default null)
returns table(id uuid, name text, age integer, gender text, city text, job text, bio text,
              looking_for text, interests text[], prompt_label text, prompt_answer text,
              photos text[], verified boolean, height_cm integer, languages text[],
              voice_prompt_label text, voice_path text, voice_seconds integer, distance_km integer)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds, d.km::int
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  cross join lateral public.profile_point(me) mp
  cross join lateral public.profile_point(p) pp
  cross join lateral (select case when pp.lat is not null and mp.lat is not null
                              then public.km_between(mp.lat, mp.lng, pp.lat, pp.lng) end as km) d
  where p.id <> me.id
    and p.onboarded and not p.is_official and public.visible_to_me(p)
    and cardinality(p.photos) > 0
    and (max_km is null or mp.lat is null
         or d.km <= max_km
         or (d.km is null and lower(trim(split_part(p.city, ',', 1))) = lower(trim(split_part(me.city, ',', 1)))))
    and not exists (select 1 from public.likes l where l.from_user = me.id and l.to_user = p.id)
    and not exists (select 1 from public.passes s where s.from_user = me.id and s.to_user = p.id)
    and not exists (select 1 from public.matches m
                    where (m.user_a, m.user_b) in ((me.id, p.id), (p.id, me.id)))
    and (me.interested_in in ('', 'Everyone')
         or (me.interested_in = 'Women' and p.gender = 'Woman')
         or (me.interested_in = 'Men' and p.gender = 'Man'))
    and (p.is_bot or p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by coalesce(p.boosted_until > now(), false) desc, d.km nulls last, p.updated_at desc
  limit max_results
$$;
revoke all on function public.discover_members(integer, integer) from public, anon;
grant execute on function public.discover_members(integer, integer) to authenticated;
revoke all on function public.record_location(double precision, double precision) from public, anon;
revoke all on function public.clear_location() from public, anon;
grant execute on function public.record_location(double precision, double precision) to authenticated;
grant execute on function public.clear_location() to authenticated;

-- ---------------------------------------------------------------------------
-- 3a. The official Everlane profile (hosts the team's Hangouts plans).
-- ---------------------------------------------------------------------------
do $$
declare
  oid uuid := '00000000-0000-4000-8000-00000000e7e7';
begin
  if not exists (select 1 from auth.users where id = oid) then
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            created_at, updated_at, confirmation_token, recovery_token,
                            email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', oid, 'authenticated', 'authenticated',
            'events@everlane.invalid', '', now(),
            '{"provider": "official", "providers": []}', '{"official": true}',
            now(), now(), '', '', '', '');
  end if;
  insert into public.profiles (id, name, bio, city, onboarded, posted, is_official)
  values (oid, 'Everlane', 'Plans hosted by the Everlane team.', '', true, true, true)
  on conflict (id) do update set is_official = true, name = 'Everlane';
end $$;

-- Official and bot accounts can't be deleted from the app.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.admins where user_id = auth.uid())
     or exists (select 1 from public.profiles where id = auth.uid() and (is_official or is_bot)) then
    raise exception 'this account can’t be deleted from the app';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

-- Hangouts near you now use live positions too, and say which plans are
-- the team's own.
drop function if exists public.hangouts_near(integer);
create function public.hangouts_near(max_km integer default null)
returns table (id uuid, kind text, title text, starts_at timestamptz, area text, venue text,
               city text, note text, looking_for text, spots int, spots_left int,
               distance_km int, mine boolean, my_status text, pending_requests int,
               host uuid, host_name text, host_age int, host_photos text[], host_verified boolean,
               host_bot boolean, host_official boolean)
language sql stable security definer set search_path = public as $$
  select h.id, h.kind, h.title, h.starts_at, h.area,
         case when h.host = me.id or r.status = 'accepted' then h.venue else '' end,
         h.city, h.note, h.looking_for, h.spots,
         greatest(h.spots - (select count(*) from public.hangout_requests a
                              where a.hangout = h.id and a.status = 'accepted')::int, 0),
         d.km::int, h.host = me.id, r.status,
         case when h.host = me.id then (select count(*) from public.hangout_requests a
                                         where a.hangout = h.id and a.status = 'pending')::int else 0 end,
         p.id, p.name, coalesce(extract(year from age(p.birthday))::int, 0), p.photos,
         p.verified, p.is_bot, p.is_official
    from public.hangouts h
    join public.profiles p on p.id = h.host
    join public.profiles me on me.id = auth.uid()
    left join public.hangout_requests r on r.hangout = h.id and r.member = me.id
    cross join lateral public.profile_point(me) mp
    cross join lateral (select case when h.lat is not null and mp.lat is not null
                                then public.km_between(mp.lat, mp.lng, h.lat, h.lng) end as km) d
   where not h.cancelled and not p.is_bot
     and h.starts_at > now() - interval '2 hours'
     and (h.host = me.id or ((p.is_official or public.visible_to_me(p))
          and (max_km is null or mp.lat is null or d.km is null or d.km <= max_km)))
   order by h.host = me.id desc, h.starts_at
   limit 100
$$;
revoke all on function public.hangouts_near(integer) from public, anon;
grant execute on function public.hangouts_near(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 3b. Admin: host plans as Everlane, see and answer requests to them.
-- ---------------------------------------------------------------------------
create or replace function public.admin_create_hangout(kind text, title text, starts_at timestamptz,
  area text, venue text, city text, note text, looking_for text, spots int)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  perform public.require_admin('bots');
  if starts_at < now() then raise exception 'pick a time in the future'; end if;
  insert into public.hangouts (host, kind, title, starts_at, area, venue, city, note, looking_for, spots)
  values ('00000000-0000-4000-8000-00000000e7e7', kind, trim(title), starts_at, trim(area), trim(venue),
          trim(city), trim(note), trim(looking_for), spots)
  returning id into made;
  perform public.log_admin('hangout_create', null, jsonb_build_object('id', made, 'title', trim(title)));
  return made;
end $$;

create or replace function public.admin_hangout_requests()
returns table (hangout uuid, title text, starts_at timestamptz, city text, member uuid, member_name text,
               member_email text, member_city text, member_verified boolean, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  return query
    select r.hangout, h.title, h.starts_at, h.city, r.member, p.name, coalesce(u.email, u.phone, '')::text,
           p.city, p.verified, r.status, r.created_at
      from public.hangout_requests r
      join public.hangouts h on h.id = r.hangout and h.host = '00000000-0000-4000-8000-00000000e7e7' and not h.cancelled
      join public.profiles p on p.id = r.member
      left join auth.users u on u.id = r.member
     order by (r.status = 'pending') desc, r.created_at desc
     limit 500;
end $$;

create or replace function public.admin_answer_hangout_request(plan uuid, who uuid, accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  if not exists (select 1 from public.hangouts where id = plan and host = '00000000-0000-4000-8000-00000000e7e7') then
    raise exception 'not an Everlane plan';
  end if;
  update public.hangout_requests
     set status = case when accept then 'accepted' else 'declined' end
   where hangout = plan and member = who;
  perform public.log_admin(case when accept then 'hangout_accept' else 'hangout_decline' end, who,
                           jsonb_build_object('plan', plan));
end $$;

-- admin_hangouts: cancel instead of delete for the team's own plans too.
create or replace function public.admin_cancel_hangouts(ids uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  perform public.require_admin('bots');
  update public.hangouts set cancelled = true where id = any (ids) and not cancelled;
  get diagnostics n = row_count;
  perform public.log_admin('hangouts_cancel', null, jsonb_build_object('count', n));
  return n;
end $$;

revoke all on function public.admin_create_hangout(text, text, timestamptz, text, text, text, text, text, int) from public, anon;
revoke all on function public.admin_hangout_requests() from public, anon;
revoke all on function public.admin_answer_hangout_request(uuid, uuid, boolean) from public, anon;
revoke all on function public.admin_cancel_hangouts(uuid[]) from public, anon;
grant execute on function public.admin_create_hangout(text, text, timestamptz, text, text, text, text, text, int) to authenticated;
grant execute on function public.admin_hangout_requests() to authenticated;
grant execute on function public.admin_answer_hangout_request(uuid, uuid, boolean) to authenticated;
grant execute on function public.admin_cancel_hangouts(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Membership plans: what each tier is called and includes.
-- ---------------------------------------------------------------------------
create table if not exists public.plans (
  plan text primary key check (plan in ('free', 'plus', 'gold', 'platinum')),
  position int not null default 0,
  title text not null,
  tagline text not null default '',
  daily_likes int not null check (daily_likes between 0 and 10000),
  weekly_sparks int not null default 0 check (weekly_sparks between 0 and 1000),
  monthly_boosts int not null default 0 check (monthly_boosts between 0 and 1000),
  perks text[] not null default '{}',
  highlight text not null default '',        -- e.g. "Most popular"
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.plans (plan, position, title, tagline, daily_likes, weekly_sparks, monthly_boosts, perks, highlight) values
  ('free', 0, 'Free', 'The essential dating experience', 8, 1, 0, array[
     '8 likes each day', '1 Spark each week to stand out',
     'Like profiles and match when interest is mutual', 'Message your matches',
     'A Chemistry summary with each person',
     'Blocking, reporting, privacy controls and account deletion'], ''),
  ('plus', 1, 'Plus', 'Simple, affordable upgrade', 25, 1, 0, array[
     'Everything in Free', '25 likes each day', 'Filter by relationship intentions',
     'A fuller Chemistry explanation, including where you differ',
     'Rewind your last accidental pass'], ''),
  ('gold', 2, 'Gold', 'The mainstream premium tier', 50, 2, 2, array[
     'Everything in Plus', 'See who has liked you', '50 likes each day',
     '2 Sparks each week', '2 profile boosts each month'], 'Most popular'),
  ('platinum', 3, 'Platinum', 'The full-featured premium experience', 100, 3, 5, array[
     'Everything in Gold', '100 likes each day', '3 Sparks each week',
     '5 profile boosts each month', 'A detailed Chemistry report, area by area',
     'Hangouts: host or join plans nearby'], '')
on conflict (plan) do nothing;

alter table public.plans enable row level security;
revoke all on public.plans from anon, authenticated;
grant select on public.plans to anon, authenticated;
drop policy if exists "plans readable" on public.plans;
create policy "plans readable" on public.plans for select using (true);

-- item: {plan, title, tagline, daily_likes, weekly_sparks, monthly_boosts, perks[], highlight, active}
create or replace function public.admin_save_plan(item jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  update public.plans set
    title = coalesce(nullif(trim(item->>'title'), ''), title),
    tagline = coalesce(item->>'tagline', tagline),
    daily_likes = coalesce((item->>'daily_likes')::int, daily_likes),
    weekly_sparks = coalesce((item->>'weekly_sparks')::int, weekly_sparks),
    monthly_boosts = coalesce((item->>'monthly_boosts')::int, monthly_boosts),
    perks = case when jsonb_typeof(item->'perks') = 'array'
              then array(select trim(x) from jsonb_array_elements_text(item->'perks') x where trim(x) <> '')
              else perks end,
    highlight = coalesce(item->>'highlight', highlight),
    active = case when item->>'plan' = 'free' then true else coalesce((item->>'active')::boolean, active) end,
    updated_at = now()
  where plan = item->>'plan';
  if not found then raise exception 'no such plan'; end if;
  perform public.log_admin('plan_edit', null, jsonb_build_object('plan', item->>'plan'));
end $$;
revoke all on function public.admin_save_plan(jsonb) from public, anon;
grant execute on function public.admin_save_plan(jsonb) to authenticated;

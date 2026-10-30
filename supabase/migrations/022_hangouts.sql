-- Hangouts: members host small plans (dinner, a movie, coffee...) and
-- others ask to join. The host accepts or declines; the exact venue is
-- only shown to accepted guests. Plans near you (by city centre) show
-- first. Only real members host plans: an automated profile must never
-- agree to meet someone at a real place. Admins can list and remove plans.

create table if not exists public.hangouts (
  id uuid primary key default gen_random_uuid(),
  host uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('dinner', 'movie', 'coffee', 'drinks', 'outdoors')),
  title text not null check (length(title) between 1 and 60),
  starts_at timestamptz not null,
  area text not null default '',          -- shown to everyone, e.g. "Kurla"
  venue text not null default '',         -- exact place, guests only
  city text not null default '',
  lat double precision,
  lng double precision,
  note text not null default '' check (length(note) <= 140),
  looking_for text not null default '' check (length(looking_for) <= 80),
  spots int not null default 2 check (spots between 1 and 8),
  cancelled boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists hangouts_starts on public.hangouts (starts_at);

create table if not exists public.hangout_requests (
  hangout uuid not null references public.hangouts (id) on delete cascade,
  member uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  primary key (hangout, member)
);

alter table public.hangouts enable row level security;
alter table public.hangout_requests enable row level security;
-- Everything goes through the functions below.
revoke all on public.hangouts, public.hangout_requests from anon, authenticated;

-- A plan's city decides where it shows; its coordinates come from the city.
create or replace function public.locate_hangout()
returns trigger language plpgsql set search_path = public as $$
begin
  select p.lat, p.lng into new.lat, new.lng from public.city_point(new.city) p;
  return new;
end $$;
drop trigger if exists hangouts_locate on public.hangouts;
create trigger hangouts_locate before insert or update of city on public.hangouts
  for each row execute function public.locate_hangout();

-- Upcoming plans within max_km of you (all of them when your city is
-- unknown or max_km is null), plus your own. Includes the host's card,
-- your request status, and the venue only for the host and accepted guests.
create or replace function public.hangouts_near(max_km integer default null)
returns table (id uuid, kind text, title text, starts_at timestamptz, area text, venue text,
               city text, note text, looking_for text, spots int, spots_left int,
               distance_km int, mine boolean, my_status text, pending_requests int,
               host uuid, host_name text, host_age int, host_photos text[], host_verified boolean,
               host_bot boolean)
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
         p.verified, p.is_bot
    from public.hangouts h
    join public.profiles p on p.id = h.host
    join public.profiles me on me.id = auth.uid()
    left join public.hangout_requests r on r.hangout = h.id and r.member = me.id
    cross join lateral (select case when h.lat is not null and me.lat is not null
                                then public.km_between(me.lat, me.lng, h.lat, h.lng) end as km) d
   where not h.cancelled and not p.is_bot
     and h.starts_at > now() - interval '2 hours'
     and (h.host = me.id or (public.visible_to_me(p)
          and (max_km is null or me.lat is null or d.km is null or d.km <= max_km)))
   order by h.host = me.id desc, h.starts_at
   limit 100
$$;

create or replace function public.host_hangout(kind text, title text, starts_at timestamptz,
  area text, venue text, city text, note text, looking_for text, spots int)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and is_bot) then
    raise exception 'automated profiles can’t host plans';
  end if;
  if starts_at < now() - interval '1 hour' then raise exception 'pick a time in the future'; end if;
  insert into public.hangouts (host, kind, title, starts_at, area, venue, city, note, looking_for, spots)
  values (auth.uid(), kind, trim(title), starts_at, trim(area), trim(venue),
          coalesce(nullif(trim(city), ''), (select p.city from public.profiles p where p.id = auth.uid()), ''),
          trim(note), trim(looking_for), spots)
  returning id into made;
  return made;
end $$;

create or replace function public.cancel_hangout(plan uuid)
returns void language sql security definer set search_path = public as $$
  update public.hangouts set cancelled = true where id = plan and host = auth.uid()
$$;

-- Ask to join; the host accepts or declines.
create or replace function public.request_hangout(plan uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  h public.hangouts;
  me uuid := auth.uid();
begin
  select * into h from public.hangouts where id = plan and not cancelled;
  if not found then raise exception 'plan not found'; end if;
  if h.host = me then raise exception 'this is your plan'; end if;
  insert into public.hangout_requests (hangout, member) values (plan, me)
  on conflict (hangout, member) do nothing;
  return (select status from public.hangout_requests where hangout = plan and member = me);
end $$;

-- The host's view of who asked to join their plans.
create or replace function public.hangout_requests_mine()
returns table (hangout uuid, member uuid, status text, name text, age int, photos text[], verified boolean)
language sql stable security definer set search_path = public as $$
  select r.hangout, r.member, r.status, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0), p.photos, p.verified
    from public.hangout_requests r
    join public.hangouts h on h.id = r.hangout and h.host = auth.uid() and not h.cancelled
    join public.profiles p on p.id = r.member
   where r.status <> 'declined'
   order by r.created_at
$$;

create or replace function public.answer_hangout_request(plan uuid, who uuid, accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.hangouts where id = plan and host = auth.uid()) then
    raise exception 'not your plan';
  end if;
  update public.hangout_requests
     set status = case when accept then 'accepted' else 'declined' end
   where hangout = plan and member = who;
  -- Accepting connects you, so you can chat about the plan.
  if accept then
    insert into public.likes (from_user, to_user, target, comment)
    values (auth.uid(), who, 'hangout', '') on conflict do nothing;
    insert into public.likes (from_user, to_user, target, comment)
    values (who, auth.uid(), 'hangout', '') on conflict do nothing;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Admin: list and delete plans.
-- ---------------------------------------------------------------------------
create or replace function public.admin_hangouts()
returns table (id uuid, kind text, title text, starts_at timestamptz, area text, venue text,
               city text, note text, spots int, cancelled boolean, host uuid, host_name text,
               host_bot boolean, requests int, accepted int, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  return query
    select h.id, h.kind, h.title, h.starts_at, h.area, h.venue, h.city, h.note, h.spots,
           h.cancelled, h.host, p.name, p.is_bot,
           (select count(*) from public.hangout_requests r where r.hangout = h.id)::int,
           (select count(*) from public.hangout_requests r where r.hangout = h.id and r.status = 'accepted')::int,
           h.created_at
      from public.hangouts h join public.profiles p on p.id = h.host
     order by h.starts_at desc
     limit 500;
end $$;

create or replace function public.admin_delete_hangouts(ids uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  perform public.require_admin('bots');
  delete from public.hangouts where id = any (ids);
  get diagnostics n = row_count;
  perform public.log_admin('hangouts_delete', null, jsonb_build_object('count', n));
  return n;
end $$;

revoke all on function public.locate_hangout() from public, anon, authenticated;
revoke all on function public.hangouts_near(integer) from public, anon;
revoke all on function public.host_hangout(text, text, timestamptz, text, text, text, text, text, int) from public, anon;
revoke all on function public.cancel_hangout(uuid) from public, anon;
revoke all on function public.request_hangout(uuid) from public, anon;
revoke all on function public.hangout_requests_mine() from public, anon;
revoke all on function public.answer_hangout_request(uuid, uuid, boolean) from public, anon;
revoke all on function public.admin_hangouts() from public, anon;
revoke all on function public.admin_delete_hangouts(uuid[]) from public, anon;
grant execute on function public.hangouts_near(integer) to authenticated;
grant execute on function public.host_hangout(text, text, timestamptz, text, text, text, text, text, int) to authenticated;
grant execute on function public.cancel_hangout(uuid) to authenticated;
grant execute on function public.request_hangout(uuid) to authenticated;
grant execute on function public.hangout_requests_mine() to authenticated;
grant execute on function public.answer_hangout_request(uuid, uuid, boolean) to authenticated;
grant execute on function public.admin_hangouts() to authenticated;
grant execute on function public.admin_delete_hangouts(uuid[]) to authenticated;

drop function if exists public.admin_generate_hangouts(jsonb);

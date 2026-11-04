-- 035_hangout_expiry_voice_events.sql
-- Hangouts push people to actually meet:
-- 1. A member's plan lives for 24 hours. If nobody has been accepted by then
--    it drops off the feed. Plans with an accepted guest stay up. The team's
--    own plans (admin_create_hangout) and older plans have no expiry.
-- 2. The host sets an icebreaker prompt, and asking to join means answering it
--    with a voice note of up to 20 seconds. No typed "hi". The host listens
--    before accepting. Plans without a prompt (the team's) need no voice note.
-- 3. Accepting starts a 2-hour window to lock in the time and place in chat.
-- 4. Plans can carry an event tag (concert, sports, comedy, movie) so people
--    with a spare ticket can find a +1.
-- Expiry is applied when plans are read, so no scheduled job is needed.

alter table public.hangouts
  add column if not exists prompt text not null default ''
    check (length(prompt) <= 120),
  add column if not exists event_tag text not null default ''
    check (event_tag in ('', 'concert', 'sports', 'comedy', 'movie')),
  add column if not exists expires_at timestamptz;

alter table public.hangout_requests
  add column if not exists voice_path text not null default '',
  add column if not exists voice_seconds int not null default 0
    check (voice_seconds between 0 and 20),
  add column if not exists accepted_at timestamptz;

-- A plan is live until it expires, unless someone has been accepted.
create or replace function public.hangout_live(h public.hangouts)
returns boolean language sql stable security definer set search_path = public as $$
  select not h.cancelled
     and (h.expires_at is null or h.expires_at > now()
          or exists (select 1 from public.hangout_requests a
                      where a.hangout = h.id and a.status = 'accepted'))
$$;

drop function if exists public.hangouts_near(integer);
create function public.hangouts_near(max_km integer default null)
returns table (id uuid, kind text, title text, starts_at timestamptz, area text, venue text,
               city text, note text, looking_for text, spots int, spots_left int,
               distance_km int, mine boolean, my_status text, pending_requests int,
               host uuid, host_name text, host_age int, host_photos text[], host_verified boolean,
               host_bot boolean, host_official boolean,
               prompt text, event_tag text, expires_at timestamptz, my_accepted_at timestamptz)
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
         p.verified, p.is_bot, p.is_official,
         h.prompt, h.event_tag, h.expires_at, r.accepted_at
    from public.hangouts h
    join public.profiles p on p.id = h.host
    join public.profiles me on me.id = auth.uid()
    left join public.hangout_requests r on r.hangout = h.id and r.member = me.id
    cross join lateral public.profile_point(me) mp
    cross join lateral (select case when h.lat is not null and mp.lat is not null
                                then public.km_between(mp.lat, mp.lng, h.lat, h.lng) end as km) d
   where public.hangout_live(h) and not p.is_bot
     and h.starts_at > now() - interval '2 hours'
     and (h.host = me.id or ((p.is_official or public.visible_to_me(p))
          and (max_km is null or mp.lat is null or d.km is null or d.km <= max_km)))
   order by h.host = me.id desc, h.starts_at
   limit 100
$$;

drop function if exists public.host_hangout(text, text, timestamptz, text, text, text, text, text, int);
create function public.host_hangout(kind text, title text, starts_at timestamptz,
  area text, venue text, city text, note text, looking_for text, spots int,
  prompt text default '', event_tag text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and is_bot) then
    raise exception 'automated profiles can’t host plans';
  end if;
  if starts_at < now() - interval '1 hour' then raise exception 'pick a time in the future'; end if;
  if length(trim(coalesce(prompt, ''))) = 0 then
    raise exception 'add an icebreaker for people to answer';
  end if;
  insert into public.hangouts (host, kind, title, starts_at, area, venue, city, note, looking_for,
                               spots, prompt, event_tag, expires_at)
  values (auth.uid(), kind, trim(title), starts_at, trim(area), trim(venue),
          coalesce(nullif(trim(city), ''), (select p.city from public.profiles p where p.id = auth.uid()), ''),
          trim(note), trim(looking_for), spots, trim(prompt), coalesce(event_tag, ''),
          now() + interval '24 hours')
  returning id into made;
  return made;
end $$;

-- Ask to join by answering the host's prompt with a voice note.
drop function if exists public.request_hangout(uuid);
create function public.request_hangout(plan uuid, voice_path text default '',
                                       voice_seconds int default 0)
returns text language plpgsql security definer set search_path = public as $$
declare
  h public.hangouts;
  me uuid := auth.uid();
begin
  select * into h from public.hangouts where id = plan;
  if not found or not public.hangout_live(h) then raise exception 'this plan has ended'; end if;
  if h.host = me then raise exception 'this is your plan'; end if;
  if h.prompt <> '' then
    if coalesce(voice_path, '') = '' or voice_seconds not between 1 and 20 then
      raise exception 'answer the icebreaker with a voice note of up to 20 seconds';
    end if;
    -- Only a recording from your own folder in the voice bucket.
    if split_part(voice_path, '/', 1) <> me::text then raise exception 'not your recording'; end if;
  end if;
  insert into public.hangout_requests (hangout, member, voice_path, voice_seconds)
  values (plan, me, coalesce(voice_path, ''), coalesce(voice_seconds, 0))
  on conflict (hangout, member) do nothing;
  return (select status from public.hangout_requests where hangout = plan and member = me);
end $$;

-- The host's view of who asked to join, with their voice notes.
drop function if exists public.hangout_requests_mine();
create function public.hangout_requests_mine()
returns table (hangout uuid, member uuid, status text, name text, age int, photos text[],
               verified boolean, voice_path text, voice_seconds int, accepted_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.hangout, r.member, r.status, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0), p.photos, p.verified,
         r.voice_path, r.voice_seconds, r.accepted_at
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
     set status = case when accept then 'accepted' else 'declined' end,
         accepted_at = case when accept then now() end
   where hangout = plan and member = who;
  -- Accepting connects you, so you can lock in the time and place in chat.
  if accept then
    insert into public.likes (from_user, to_user, target, comment)
    values (auth.uid(), who, 'hangout', '') on conflict do nothing;
    insert into public.likes (from_user, to_user, target, comment)
    values (who, auth.uid(), 'hangout', '') on conflict do nothing;
  end if;
end $$;

revoke all on function public.hangout_live(public.hangouts) from public, anon;
revoke all on function public.hangouts_near(integer) from public, anon;
revoke all on function public.host_hangout(text, text, timestamptz, text, text, text, text, text, int, text, text) from public, anon;
revoke all on function public.request_hangout(uuid, text, int) from public, anon;
revoke all on function public.hangout_requests_mine() from public, anon;
grant execute on function public.hangout_live(public.hangouts) to authenticated;
grant execute on function public.hangouts_near(integer) to authenticated;
grant execute on function public.host_hangout(text, text, timestamptz, text, text, text, text, text, int, text, text) to authenticated;
grant execute on function public.request_hangout(uuid, text, int) to authenticated;
grant execute on function public.hangout_requests_mine() to authenticated;

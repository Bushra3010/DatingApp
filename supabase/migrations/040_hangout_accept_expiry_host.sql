-- Hangouts:
--  1. When a host accepts you, the match that connects you is marked as
--     coming from Hangouts, so the app says "Your hangout request is
--     accepted" instead of celebrating a match.
--  2. A plan stays up at most 24 hours after it's posted and comes down 30
--     minutes after it starts, whichever is first; a job deletes it then.
--  3. Plans the team hosts as Everlane can show who from the team hosts
--     them ("host_label"), still under the official Everlane profile.

alter table public.matches add column if not exists origin text not null default '';
alter table public.hangouts add column if not exists host_label text not null default ''
  check (char_length(host_label) <= 40);

create or replace function public.match_on_mutual_like()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.likes
             where from_user = new.to_user and to_user = new.from_user) then
    insert into public.matches (user_a, user_b, origin)
    values (least(new.from_user, new.to_user), greatest(new.from_user, new.to_user),
            case when new.target = 'hangout' then 'hangout' else '' end)
    on conflict do nothing;
  end if;
  return new;
end $$;

-- Live until 24 hours after posting or 30 minutes after it starts.
create or replace function public.hangout_live(h public.hangouts)
returns boolean language sql stable security definer set search_path = public as $$
  select not h.cancelled
     and now() < least(h.created_at + interval '24 hours', h.starts_at + interval '30 minutes')
$$;

create or replace function public.delete_ended_hangouts()
returns int language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  delete from public.hangouts
   where now() >= least(created_at + interval '24 hours', starts_at + interval '30 minutes');
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.delete_ended_hangouts() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'hangouts-cleanup';
    perform cron.schedule('hangouts-cleanup', '*/5 * * * *', 'select public.delete_ended_hangouts()');
  end if;
end $$;

create or replace function public.hangouts_near(max_km integer default null)
returns TABLE(id uuid, kind text, title text, starts_at timestamp with time zone, area text, venue text, city text, note text, looking_for text, spots integer, spots_left integer, distance_km integer, mine boolean, my_status text, pending_requests integer, host uuid, host_name text, host_age integer, host_photos text[], host_verified boolean, host_bot boolean, host_official boolean, prompt text, event_tag text, expires_at timestamp with time zone, my_accepted_at timestamp with time zone)
 language sql stable security definer set search_path = public as $$
  select h.id, h.kind, h.title, h.starts_at, h.area,
         case when h.host = me.id or r.status = 'accepted' then h.venue else '' end,
         h.city, h.note, h.looking_for, h.spots,
         greatest(h.spots - (select count(*) from public.hangout_requests a
                              where a.hangout = h.id and a.status = 'accepted')::int, 0),
         d.km::int, h.host = me.id, r.status,
         case when h.host = me.id then (select count(*) from public.hangout_requests a
                                         where a.hangout = h.id and a.status = 'pending')::int else 0 end,
         p.id, case when p.is_official and h.host_label <> '' then h.host_label else p.name end,
         coalesce(extract(year from age(p.birthday))::int, 0), p.photos,
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
     and (h.host = me.id or ((p.is_official or public.visible_to_me(p))
          and (max_km is null or mp.lat is null or d.km is null or d.km <= max_km)))
   order by h.host = me.id desc, h.starts_at
   limit 100
$$;

drop function if exists public.admin_create_hangout(text, text, timestamptz, text, text, text, text, text, int);
create or replace function public.admin_create_hangout(kind text, title text, starts_at timestamptz,
  area text, venue text, city text, note text, looking_for text, spots int, host_name text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  perform public.require_admin('bots');
  if starts_at < now() then raise exception 'pick a time in the future'; end if;
  insert into public.hangouts (host, kind, title, starts_at, area, venue, city, note, looking_for, spots,
                               host_label, expires_at)
  values ('00000000-0000-4000-8000-00000000e7e7', kind, trim(title), starts_at, trim(area), trim(venue),
          trim(city), trim(note), trim(looking_for), spots, left(trim(coalesce(host_name, '')), 40),
          least(now() + interval '24 hours', starts_at + interval '30 minutes'))
  returning id into made;
  perform public.log_admin('hangout_create', null, jsonb_build_object('id', made, 'title', trim(title),
                                                                     'host_name', host_name));
  return made;
end $$;
revoke all on function public.admin_create_hangout(text, text, timestamptz, text, text, text, text, text, int, text) from public, anon;
grant execute on function public.admin_create_hangout(text, text, timestamptz, text, text, text, text, text, int, text) to authenticated;

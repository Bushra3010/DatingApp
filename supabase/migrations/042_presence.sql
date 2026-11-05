-- Presence on Discover cards: "Online", "Recently online" or "New here",
-- in place of the old "Swipe or tap" hint.
--
-- The app reports activity with touch_presence() while it's open. Members
-- can hide their online status (Preferences → Show when I'm online);
-- automated profiles never show any, since they aren't real activity.

alter table public.profiles
  add column if not exists last_seen_at timestamptz,
  add column if not exists show_online_status boolean not null default true;

create or replace function public.touch_presence()
returns void language sql security definer set search_path = public as $$
  update public.profiles set last_seen_at = now()
   where id = auth.uid() and (last_seen_at is null or last_seen_at < now() - interval '1 minute')
$$;

create or replace function public.set_show_online(p_show boolean)
returns void language sql security definer set search_path = public as $$
  update public.profiles set show_online_status = coalesce(p_show, true) where id = auth.uid()
$$;

revoke all on function public.touch_presence() from public, anon;
revoke all on function public.set_show_online(boolean) from public, anon;
grant execute on function public.touch_presence() to authenticated;
grant execute on function public.set_show_online(boolean) to authenticated;

drop function if exists public.discover_members(integer, integer);
create function public.discover_members(max_results integer default 50, max_km integer default null)
returns table(id uuid, name text, age integer, gender text, city text, job text, bio text,
              looking_for text, interests text[], prompt_label text, prompt_answer text,
              photos text[], verified boolean, height_cm integer, languages text[],
              voice_prompt_label text, voice_path text, voice_seconds integer, distance_km integer,
              last_seen_at timestamptz, joined_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds, d.km::int,
         -- Presence: only for real members who share it (never for
         -- automated profiles, which have no real activity to show).
         case when not p.is_bot and p.show_online_status then p.last_seen_at end,
         case when not p.is_bot then (select u.created_at from auth.users u where u.id = p.id) end
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  cross join (select coalesce((select value from public.app_config where key = 'algo'), '{}') as w) cfg
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
  -- Boosted first, then the admin's weights (Matching → Algorithm): how
  -- close, how recently active, verified, shared interests, how complete.
  order by coalesce(p.boosted_until > now(), false) desc,
    coalesce((cfg.w->>'distance')::numeric, 40) * case when d.km is null then 0.5 else greatest(0, 1 - d.km / greatest(coalesce(max_km, 100), 1)::numeric) end
    + coalesce((cfg.w->>'recent')::numeric, 20) * greatest(0, 1 - extract(epoch from now() - p.updated_at) / (14 * 86400))::numeric
    + coalesce((cfg.w->>'verified')::numeric, 15) * (case when p.verified then 1 else 0 end)
    + coalesce((cfg.w->>'shared_interests')::numeric, 15) * least(1, coalesce(cardinality(array(select unnest(p.interests) intersect select unnest(me.interests))), 0) / 3.0)
    + coalesce((cfg.w->>'complete_profile')::numeric, 10) * ((case when p.bio <> '' then 1 else 0 end) + (case when cardinality(p.photos) > 1 then 1 else 0 end)
                                                        + (case when p.prompt_answer <> '' then 1 else 0 end) + (case when cardinality(p.interests) > 0 then 1 else 0 end)) / 4.0
    desc,
    d.km nulls last, p.updated_at desc
  limit max_results
$$;
revoke all on function public.discover_members(integer, integer) from public, anon;
grant execute on function public.discover_members(integer, integer) to authenticated;

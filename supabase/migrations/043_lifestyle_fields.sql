-- Lifestyle details for Discover filters: drinking, smoking, education
-- and family plans. Optional on a profile (empty = not said); members set
-- them in Edit profile. Automated profiles get plausible values so the
-- filters don't empty the deck.

alter table public.profiles
  add column if not exists drinking text not null default ''
    check (drinking in ('', 'never', 'socially', 'regularly')),
  add column if not exists smoking text not null default ''
    check (smoking in ('', 'non_smoker', 'socially', 'smoker')),
  add column if not exists education text not null default ''
    check (education in ('', 'high_school', 'graduate', 'postgraduate', 'phd')),
  add column if not exists family_plans text not null default ''
    check (family_plans in ('', 'wants_kids', 'open', 'doesnt_want', 'has_kids'));

create or replace function public.fill_bot_answers()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.is_bot then
    if cardinality(new.interests) = 0 then new.interests := public.random_interests(); end if;
    if cardinality(new.languages) = 0 then new.languages := array['English', 'Hindi']; end if;
    if new.quiz_answers = '{}' then new.quiz_answers := public.random_quiz_answers(); end if;
    if new.drinking = '' then
      new.drinking := (array['never', 'never', 'socially', 'socially', 'socially', 'regularly'])[1 + floor(random() * 6)::int];
    end if;
    if new.smoking = '' then
      new.smoking := (array['non_smoker', 'non_smoker', 'non_smoker', 'non_smoker', 'socially', 'smoker'])[1 + floor(random() * 6)::int];
    end if;
    if new.education = '' then
      new.education := (array['graduate', 'graduate', 'graduate', 'postgraduate', 'postgraduate', 'high_school'])[1 + floor(random() * 6)::int];
    end if;
    if new.family_plans = '' then
      new.family_plans := (array['wants_kids', 'wants_kids', 'open', 'open', 'doesnt_want'])[1 + floor(random() * 5)::int];
    end if;
  end if;
  return new;
end $$;
update public.profiles set updated_at = updated_at where is_bot and (drinking = '' or smoking = '' or education = '' or family_plans = '');

drop function if exists public.discover_members(integer, integer);
create function public.discover_members(max_results integer default 50, max_km integer default null)
returns table(id uuid, name text, age integer, gender text, city text, job text, bio text,
              looking_for text, interests text[], prompt_label text, prompt_answer text,
              photos text[], verified boolean, height_cm integer, languages text[],
              voice_prompt_label text, voice_path text, voice_seconds integer, distance_km integer,
              last_seen_at timestamptz, joined_at timestamptz,
              drinking text, smoking text, education text, family_plans text)
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
         case when not p.is_bot then (select u.created_at from auth.users u where u.id = p.id) end,
         p.drinking, p.smoking, p.education, p.family_plans
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

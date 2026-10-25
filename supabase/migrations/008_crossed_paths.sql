-- Everlane: crossed paths (Happn-style). Sharing is opt-in in the app.
--
-- Only a ~1 km area (coordinates rounded down to 0.01°, kept as the centre
-- of that square) and the day are stored, never an exact spot or a time.
-- Areas older than 30 days are deleted whenever the member records a new
-- one, and all of them when they turn sharing off.

create table if not exists public.area_visits (
  user_id uuid not null references public.profiles (id) on delete cascade,
  cell text not null,
  area_lat double precision not null,
  area_lng double precision not null,
  day date not null default current_date,
  primary key (user_id, cell, day)
);
create index if not exists area_visits_cell_day_idx on public.area_visits (cell, day);
alter table public.area_visits enable row level security;
-- Members may see and delete their own areas; writes go through
-- record_area() so the rounding can't be skipped.
drop policy if exists "Members read their own areas" on public.area_visits;
create policy "Members read their own areas" on public.area_visits
  for select to authenticated using (user_id = auth.uid());

create or replace function public.record_area(lat double precision, lng double precision)
returns void language plpgsql security definer set search_path = public as $$
declare
  i int := floor(lat / 0.01);
  j int := floor(lng / 0.01);
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if lat not between -90 and 90 or lng not between -180 and 180 then
    raise exception 'bad coordinates';
  end if;
  insert into public.area_visits (user_id, cell, area_lat, area_lng)
  values (auth.uid(), i || ':' || j, (i + 0.5) * 0.01, (j + 0.5) * 0.01)
  on conflict do nothing;
  delete from public.area_visits
   where user_id = auth.uid() and day < current_date - 30;
end $$;

create or replace function public.clear_my_areas()
returns void language sql security definer set search_path = public as $$
  delete from public.area_visits where user_id = auth.uid()
$$;

-- People who were in one of your areas on the same day in the last 14 days,
-- with the area you most recently shared and how many times.
create or replace function public.crossed_paths()
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int,
               area_lat double precision, area_lng double precision,
               last_day date, times int)
language sql stable security definer set search_path = public as $$
  with shared as (
    select v.user_id, v.cell, v.area_lat, v.area_lng, v.day
    from public.area_visits v
    join public.area_visits mine
      on mine.cell = v.cell and mine.day = v.day and mine.user_id = auth.uid()
    where v.user_id <> auth.uid() and v.day >= current_date - 14
  ), per as (
    select user_id, count(*)::int as times, max(day) as last_day
    from shared group by user_id
  ), latest as (
    select distinct on (user_id) user_id, area_lat, area_lng
    from shared order by user_id, day desc
  )
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds, l.area_lat, l.area_lng, per.last_day, per.times
  from per
  join latest l on l.user_id = per.user_id
  join public.profiles p on p.id = per.user_id
  join public.profiles me on me.id = auth.uid()
  where p.onboarded and public.visible_to_me(p)
    and cardinality(p.photos) > 0
    and not exists (select 1 from public.passes s
                    where s.from_user = me.id and s.to_user = p.id)
    and (me.interested_in in ('', 'Everyone')
         or (me.interested_in = 'Women' and p.gender = 'Woman')
         or (me.interested_in = 'Men' and p.gender = 'Man'))
    and (p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by per.last_day desc, per.times desc
  limit 100
$$;

revoke all on function public.record_area(double precision, double precision) from public, anon;
revoke all on function public.clear_my_areas() from public, anon;
revoke all on function public.crossed_paths() from public, anon;
grant execute on function public.record_area(double precision, double precision) to authenticated;
grant execute on function public.clear_my_areas() to authenticated;
grant execute on function public.crossed_paths() to authenticated;

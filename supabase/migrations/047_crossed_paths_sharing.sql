-- Crossed paths: whether a member shares their area is kept on the profile,
-- so it survives a reload, and the app records the area on every visit while
-- it's on (not only when the Crossed paths screen is opened).
alter table public.profiles
  add column if not exists share_area boolean not null default false;

update public.profiles p set share_area = true
 where exists (select 1 from public.area_visits v where v.user_id = p.id);

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
  update public.profiles set share_area = true where id = auth.uid() and not share_area;
end $$;

create or replace function public.clear_my_areas()
returns void language sql security definer set search_path = public as $$
  delete from public.area_visits where user_id = auth.uid();
  update public.profiles set share_area = false where id = auth.uid();
$$;

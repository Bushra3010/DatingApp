-- Hosting a plan no longer needs an icebreaker (it was removed from the
-- form): without one, joining is a plain request. The post's expiry
-- matches hangout_live(): 24 hours, or 30 minutes after it starts.
create or replace function public.host_hangout(kind text, title text, starts_at timestamptz, area text,
  venue text, city text, note text, looking_for text, spots integer, prompt text default '',
  event_tag text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and is_bot) then
    raise exception 'automated profiles can’t host plans';
  end if;
  if starts_at < now() then raise exception 'pick a time in the future'; end if;
  insert into public.hangouts (host, kind, title, starts_at, area, venue, city, note, looking_for,
                               spots, prompt, event_tag, expires_at)
  values (auth.uid(), kind, trim(title), starts_at, trim(area), trim(venue),
          coalesce(nullif(trim(city), ''), (select p.city from public.profiles p where p.id = auth.uid()), ''),
          trim(note), trim(looking_for), spots, trim(coalesce(prompt, '')), coalesce(event_tag, ''),
          least(now() + interval '24 hours', starts_at + interval '30 minutes'))
  returning id into made;
  return made;
end $$;

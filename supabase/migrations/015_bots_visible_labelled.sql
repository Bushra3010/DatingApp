-- Bots are now shown to every member, not just test accounts, so the app
-- doesn't look empty. The app always labels them as "Sample profile"
-- (it asks sample_profile_ids() which ones they are), so nobody mistakes
-- a bot for a real person. Other test accounts are unchanged: they still
-- only see, and are seen by, test accounts.

create or replace function public.visible_to_me(p public.profiles)
returns boolean language sql stable security definer set search_path = public as $$
  select not p.blocked
     and not p.shadow_banned
     and coalesce(p.suspended_until <= now(), true)
     and (p.is_bot
          or p.is_test = coalesce((select is_test from public.profiles where id = auth.uid()), false))
$$;

-- Which profiles are bots, so the app can label them.
create or replace function public.sample_profile_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where is_bot
$$;
revoke all on function public.sample_profile_ids() from public, anon;
grant execute on function public.sample_profile_ids() to authenticated;

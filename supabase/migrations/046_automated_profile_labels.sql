-- Automated (bot) profiles are labelled in the app again (undoes
-- 031_remove_bot_labels). The Terms and Privacy Policy say so, and a paid
-- dating app can't let members take automated replies for real people.
create or replace function public.sample_profile_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where is_bot
$$;

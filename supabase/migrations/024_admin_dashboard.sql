-- Numbers for the admin panel's dashboard, all real (no estimates):
-- totals, the queues waiting on the team, a day-by-day series for the
-- last [days] days, and splits by gender, city and goal. Bots are counted
-- separately and left out of the member numbers.
create or replace function public.admin_dashboard(days int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since date := current_date - (greatest(least(days, 180), 7) - 1);
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'totals', (select jsonb_build_object(
        'members', count(*) filter (where not is_bot),
        'onboarded', count(*) filter (where not is_bot and onboarded),
        'verified', count(*) filter (where not is_bot and verified),
        'premium', count(*) filter (where not is_bot and plan <> '' and plan <> 'free'
                                     and coalesce(plan_until > now(), true)),
        'blocked', count(*) filter (where not is_bot and blocked),
        'bots', count(*) filter (where is_bot),
        'bots_live', count(*) filter (where is_bot and not blocked),
        'new_7d', (select count(*) from auth.users u join public.profiles p on p.id = u.id
                    where not p.is_bot and u.created_at > now() - interval '7 days'),
        'active_7d', (select count(*) from auth.users u join public.profiles p on p.id = u.id
                       where not p.is_bot and u.last_sign_in_at > now() - interval '7 days'))
      from public.profiles),
    'activity', jsonb_build_object(
        'likes', (select count(*) from public.likes),
        'matches', (select count(*) from public.matches),
        'messages', (select count(*) from public.messages),
        'hangouts', (select count(*) from public.hangouts where not cancelled and starts_at > now()),
        'hangout_requests', (select count(*) from public.hangout_requests)),
    'queues', jsonb_build_object(
        'reports', (select count(*) from public.reports where status = 'open'),
        'photos', (select count(*) from public.photo_reviews where status = 'pending'),
        'verifications', (select count(*) from public.verification_requests where status = 'pending')),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d,
          'signups', (select count(*) from auth.users u join public.profiles p on p.id = u.id
                       where not p.is_bot and u.created_at::date = d),
          'likes', (select count(*) from public.likes l where l.created_at::date = d),
          'matches', (select count(*) from public.matches m where m.created_at::date = d),
          'messages', (select count(*) from public.messages x where x.created_at::date = d)) order by d), '[]')
        from generate_series(since, current_date, interval '1 day') g(d0), lateral (select d0::date as d) s),
    'gender', (select coalesce(jsonb_object_agg(k, n), '{}') from (
        select coalesce(nullif(gender, ''), 'Not set') k, count(*) n
          from public.profiles where not is_bot group by 1) s),
    'goals', (select coalesce(jsonb_object_agg(k, n), '{}') from (
        select coalesce(nullif(looking_for, ''), 'Not set') k, count(*) n
          from public.profiles where not is_bot group by 1) s),
    'cities', (select coalesce(jsonb_agg(jsonb_build_object('city', k, 'members', n, 'bots', b) order by n desc, b desc), '[]') from (
        select split_part(city, ',', 1) k,
               count(*) filter (where not is_bot) n, count(*) filter (where is_bot) b
          from public.profiles where city <> '' group by 1 order by 2 desc, 3 desc limit 12) s));
end $$;
revoke all on function public.admin_dashboard(int) from public, anon;
grant execute on function public.admin_dashboard(int) to authenticated;

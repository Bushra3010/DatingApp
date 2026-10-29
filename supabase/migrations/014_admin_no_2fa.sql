-- Admins sign in with email and password only; the authenticator-app step
-- is switched off. Every admin function and policy checks mfa_verified(),
-- so it now always passes. To require two-step sign-in again, restore the
-- check from 012:  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'

create or replace function public.mfa_verified()
returns boolean language sql stable as $$
  select true
$$;

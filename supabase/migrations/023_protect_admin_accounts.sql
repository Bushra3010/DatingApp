-- An admin account can't be deleted from the app's "Delete account" button
-- (the admin login kept disappearing after it was used to try the app).
-- Remove the admin role first in the panel's Team page, or delete the user
-- in the Supabase dashboard.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  if exists (select 1 from public.admins where user_id = auth.uid()) then
    raise exception 'admin accounts can’t be deleted from the app';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

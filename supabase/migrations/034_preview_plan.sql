-- 034_preview_plan.sql
-- Until payments go live, the plan a member picks in the app is kept on their
-- profile so it survives a reload or a new sign-in. It lives in its own column:
-- `plan` stays reserved for admins and real payments, so revenue and paid-member
-- counts are unaffected. A plan set by an admin still wins in the app.

alter table public.profiles
  add column if not exists preview_plan text not null default ''
    check (preview_plan in ('', 'free', 'plus', 'gold', 'platinum'));

create or replace function public.choose_preview_plan(p_plan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  update public.profiles
     set preview_plan = coalesce(p_plan, ''),
         updated_at = now()
   where id = auth.uid();
end $$;

revoke all on function public.choose_preview_plan(text) from public, anon;
grant execute on function public.choose_preview_plan(text) to authenticated;

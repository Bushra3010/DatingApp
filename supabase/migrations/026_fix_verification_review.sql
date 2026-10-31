-- Approving or rejecting a selfie verification failed with "column
-- reference note is ambiguous": the parameter and the column share the
-- name. The parameter is now referred to by the function's name (the panel
-- still passes it as `note`).
create or replace function public.admin_review_verification(request bigint, approve boolean, note text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
  reason text := coalesce(admin_review_verification.note, '');
begin
  perform public.require_admin('moderate');
  update public.verification_requests r
     set status = case when approve then 'approved' else 'rejected' end,
         note = case when approve then '' else reason end,
         reviewed_at = now(), reviewed_by = auth.uid()
   where r.id = request and r.status = 'pending'
  returning r.user_id into owner;
  if owner is null then raise exception 'that request was already reviewed'; end if;
  update public.profiles set verified = approve where id = owner;
  perform public.log_admin(case when approve then 'verify' else 'verify_reject' end,
                           owner, jsonb_build_object('request', request, 'note', reason));
end $$;

-- Everlane selfie verification: a member takes a live selfie burst in the
-- app (eyes open, a blink, eyes open again), it lands in a private bucket,
-- and an admin compares it with the profile photos before granting the
-- verified badge. Members can never set the badge themselves (see
-- keep_block_admin_only in 007).

-- Private: selfies are only for review, never shown on a profile.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verifications', 'verifications', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "Members upload their verification selfies" on storage.objects;
create policy "Members upload their verification selfies" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'verifications' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Admins read verification selfies" on storage.objects;
create policy "Admins read verification selfies" on storage.objects
  for select to authenticated
  using (bucket_id = 'verifications' and public.is_admin());

drop policy if exists "Admins delete verification selfies" on storage.objects;
create policy "Admins delete verification selfies" on storage.objects
  for delete to authenticated
  using (bucket_id = 'verifications' and public.is_admin());

create table if not exists public.verification_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- Storage paths in the "verifications" bucket, in the order taken.
  frames text[] not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'replaced')),
  -- Shown to the member when a request is rejected.
  note text not null default '',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid
);
create index if not exists verification_requests_pending_idx
  on public.verification_requests (status, created_at);
alter table public.verification_requests enable row level security;

-- Members see their own requests (for "pending" / "try again"); all writes
-- go through the functions below.
drop policy if exists "Members read their own verification" on public.verification_requests;
create policy "Members read their own verification" on public.verification_requests
  for select to authenticated using (user_id = auth.uid());

create or replace function public.submit_verification(frames text[])
returns bigint language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  req bigint;
begin
  if me is null then raise exception 'not signed in'; end if;
  if coalesce(array_length(frames, 1), 0) not between 3 and 8 then
    raise exception 'send 3 to 8 selfie frames';
  end if;
  if exists (select 1 from unnest(frames) f where split_part(f, '/', 1) <> me::text) then
    raise exception 'frames must be your own uploads';
  end if;
  insert into public.profiles (id) values (me) on conflict (id) do nothing;
  -- A new attempt replaces one still waiting.
  update public.verification_requests set status = 'replaced'
   where user_id = me and status = 'pending';
  insert into public.verification_requests (user_id, frames)
  values (me, frames) returning id into req;
  return req;
end $$;

create or replace function public.admin_verification_queue()
returns table (id bigint, user_id uuid, name text, photo text, frames text[],
               created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select r.id, r.user_id, coalesce(p.name, ''), coalesce(p.photos[1], ''), r.frames,
         r.created_at
  from public.verification_requests r
  join public.profiles p on p.id = r.user_id
  where r.status = 'pending'
  order by r.created_at
  limit 200;
end $$;

-- Approving grants the badge; rejecting leaves a note the member sees.
create or replace function public.admin_review_verification(
  request bigint, approve boolean, note text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  update public.verification_requests
     set status = case when approve then 'approved' else 'rejected' end,
         note = case when approve then '' else coalesce(note, '') end,
         reviewed_at = now(), reviewed_by = auth.uid()
   where id = request and status = 'pending'
  returning user_id into owner;
  if owner is null then raise exception 'that request was already reviewed'; end if;
  update public.profiles set verified = approve where id = owner;
  perform public.log_admin(case when approve then 'verify' else 'verify_reject' end,
                           owner, jsonb_build_object('request', request,
                                                     'note', coalesce(note, '')));
end $$;

revoke all on function public.submit_verification(text[]) from public, anon;
revoke all on function public.admin_verification_queue() from public, anon;
revoke all on function public.admin_review_verification(bigint, boolean, text) from public, anon;
grant execute on function public.submit_verification(text[]) to authenticated;
grant execute on function public.admin_verification_queue() to authenticated;
grant execute on function public.admin_review_verification(bigint, boolean, text) to authenticated;

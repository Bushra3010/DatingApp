-- Everlane: each signed-in member's own profile, and their photos.
-- Discovery, likes and chat still run on demo data in the app.

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null default '',
  birthday date,
  gender text not null default '',
  interested_in text not null default '',
  city text not null default '',
  job text not null default '',
  bio text not null default '',
  looking_for text not null default 'Relationship',
  interests text[] not null default '{}',
  prompt_label text not null default 'My ideal Sunday is',
  prompt_answer text not null default '',
  -- Storage paths in the "photos" bucket; the first one is the main photo.
  photos text[] not null default '{}',
  onboarding_answers jsonb not null default '{}',
  onboarded boolean not null default false,
  posted boolean not null default false,
  verified boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Members read their own profile" on public.profiles;
create policy "Members read their own profile" on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists "Members create their own profile" on public.profiles;
create policy "Members create their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists "Members update their own profile" on public.profiles;
create policy "Members update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Profile photos are meant to be seen, so the bucket is public-read; only
-- the owner can write into their own folder (<user id>/...).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/gif'])
on conflict (id) do nothing;

drop policy if exists "Members upload to their own folder" on storage.objects;
create policy "Members upload to their own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Members update their own photos" on storage.objects;
create policy "Members update their own photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Members delete their own photos" on storage.objects;
create policy "Members delete their own photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

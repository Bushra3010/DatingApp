-- Everlane: Hinge-style voice prompts. A member picks a question and records
-- an answer of up to 30 seconds; it plays on their profile.

alter table public.profiles
  add column if not exists voice_prompt_label text not null default '',
  -- Storage path in the "voice" bucket; empty when there is no recording.
  add column if not exists voice_path text not null default '',
  add column if not exists voice_seconds int not null default 0
    check (voice_seconds between 0 and 30);

-- Voice prompts are meant to be heard on the profile, so the bucket is
-- public-read like photos; only the owner writes into their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('voice', 'voice', true, 5242880, array['audio/wav', 'audio/x-wav'])
on conflict (id) do nothing;

drop policy if exists "Members upload their own voice" on storage.objects;
create policy "Members upload their own voice" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'voice' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Members delete their own voice" on storage.objects;
create policy "Members delete their own voice" on storage.objects
  for delete to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = auth.uid()::text);

-- The member cards gain the voice prompt, so the functions are recreated
-- with the extra columns.
drop function if exists public.discover_members(int);
drop function if exists public.likes_received();
drop function if exists public.my_matches();

create function public.discover_members(max_results int default 50)
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  where p.id <> me.id
    and p.onboarded and not p.blocked
    and cardinality(p.photos) > 0
    and not exists (select 1 from public.likes l
                    where l.from_user = me.id and l.to_user = p.id)
    and not exists (select 1 from public.passes s
                    where s.from_user = me.id and s.to_user = p.id)
    and not exists (select 1 from public.matches m
                    where (m.user_a, m.user_b) in ((me.id, p.id), (p.id, me.id)))
    and (me.interested_in in ('', 'Everyone')
         or (me.interested_in = 'Women' and p.gender = 'Woman')
         or (me.interested_in = 'Men' and p.gender = 'Man'))
    and (p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by p.updated_at desc
  limit max_results
$$;

create function public.likes_received()
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int,
               target text, comment text, liked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds,
         l.target, l.comment, l.created_at
  from public.likes l
  join public.profiles p on p.id = l.from_user
  where l.to_user = auth.uid() and not p.blocked
    and not exists (select 1 from public.likes back
                    where back.from_user = auth.uid() and back.to_user = l.from_user)
    and not exists (select 1 from public.passes s
                    where s.from_user = auth.uid() and s.to_user = l.from_user)
  order by l.created_at desc
$$;

create function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[], voice_prompt_label text,
               voice_path text, voice_seconds int)
language sql stable security definer set search_path = public as $$
  select m.id, m.created_at, p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds
  from public.matches m
  join public.profiles p
    on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b) and not p.blocked
  order by m.created_at desc
$$;

revoke all on function public.discover_members(int) from public, anon;
revoke all on function public.likes_received() from public, anon;
revoke all on function public.my_matches() from public, anon;
grant execute on function public.discover_members(int) to authenticated;
grant execute on function public.likes_received() to authenticated;
grant execute on function public.my_matches() to authenticated;

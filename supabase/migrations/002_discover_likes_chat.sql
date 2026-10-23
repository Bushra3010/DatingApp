-- Everlane: discovery, likes, matches and chat between real members.
--
-- Members never read each other's profiles rows directly (they hold the
-- date of birth); they get a "card" with the age instead, through the
-- security-definer functions below.

create table if not exists public.likes (
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  target text not null default 'photo',
  comment text not null default '' check (char_length(comment) <= 150),
  created_at timestamptz not null default now(),
  primary key (from_user, to_user),
  check (from_user <> to_user)
);
create index if not exists likes_to_user_idx on public.likes (to_user);

create table if not exists public.passes (
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  sender uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_match_idx on public.messages (match_id, created_at);

alter table public.likes enable row level security;
alter table public.passes enable row level security;
alter table public.matches enable row level security;
alter table public.messages enable row level security;

-- Likes: send your own; see the ones you sent or received.
drop policy if exists "Send likes" on public.likes;
create policy "Send likes" on public.likes
  for insert to authenticated with check (from_user = auth.uid());
drop policy if exists "See likes sent or received" on public.likes;
create policy "See likes sent or received" on public.likes
  for select to authenticated using (auth.uid() in (from_user, to_user));

-- Passes are private to whoever passed, and can be undone.
drop policy if exists "Own passes" on public.passes;
create policy "Own passes" on public.passes
  for all to authenticated
  using (from_user = auth.uid()) with check (from_user = auth.uid());

-- Matches are only ever created by the trigger below; either side can see
-- or end (unmatch) one.
drop policy if exists "See own matches" on public.matches;
create policy "See own matches" on public.matches
  for select to authenticated using (auth.uid() in (user_a, user_b));
drop policy if exists "Unmatch" on public.matches;
create policy "Unmatch" on public.matches
  for delete to authenticated using (auth.uid() in (user_a, user_b));

-- Messages: only the two people in a match can read or write.
drop policy if exists "Read match messages" on public.messages;
create policy "Read match messages" on public.messages
  for select to authenticated using (exists (
    select 1 from public.matches m
    where m.id = match_id and auth.uid() in (m.user_a, m.user_b)));
drop policy if exists "Send match messages" on public.messages;
create policy "Send match messages" on public.messages
  for insert to authenticated with check (sender = auth.uid() and exists (
    select 1 from public.matches m
    where m.id = match_id and auth.uid() in (m.user_a, m.user_b)));

-- A like back makes a match.
create or replace function public.match_on_mutual_like()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.likes
             where from_user = new.to_user and to_user = new.from_user) then
    insert into public.matches (user_a, user_b)
    values (least(new.from_user, new.to_user), greatest(new.from_user, new.to_user))
    on conflict do nothing;
  end if;
  return new;
end $$;

drop trigger if exists likes_make_match on public.likes;
create trigger likes_make_match after insert on public.likes
  for each row execute function public.match_on_mutual_like();

-- People to discover: finished profiles with a photo, not you, not already
-- liked, passed or matched, and where each side's "interested in" fits the
-- other's gender.
create or replace function public.discover_members(max_results int default 50)
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  where p.id <> me.id
    and p.onboarded
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

-- People who liked you and are still waiting on your answer.
create or replace function public.likes_received()
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               target text, comment text, liked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         l.target, l.comment, l.created_at
  from public.likes l
  join public.profiles p on p.id = l.from_user
  where l.to_user = auth.uid()
    and not exists (select 1 from public.likes back
                    where back.from_user = auth.uid() and back.to_user = l.from_user)
    and not exists (select 1 from public.passes s
                    where s.from_user = auth.uid() and s.to_user = l.from_user)
  order by l.created_at desc
$$;

-- Your matches, newest first, with the other person's card.
create or replace function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean)
language sql stable security definer set search_path = public as $$
  select m.id, m.created_at, p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified
  from public.matches m
  join public.profiles p
    on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b)
  order by m.created_at desc
$$;

revoke all on function public.discover_members(int) from public, anon;
revoke all on function public.likes_received() from public, anon;
revoke all on function public.my_matches() from public, anon;
grant execute on function public.discover_members(int) to authenticated;
grant execute on function public.likes_received() to authenticated;
grant execute on function public.my_matches() to authenticated;

-- Live chat, new likes and new matches.
do $$
begin
  begin alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.matches;
  exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.likes;
  exception when duplicate_object then null; end;
end $$;

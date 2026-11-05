-- Unread counts on the Messages list: when each member last opened each
-- chat, and how many messages from the other person arrived after that.

create table if not exists public.match_reads (
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (match_id, user_id)
);
alter table public.match_reads enable row level security;
revoke all on public.match_reads from anon, authenticated;

-- Opening a chat marks it read up to now. Only your own matches.
create or replace function public.mark_read(p_match uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.matches m
                  where m.id = p_match and auth.uid() in (m.user_a, m.user_b)) then
    return;
  end if;
  insert into public.match_reads (match_id, user_id, last_read_at)
  values (p_match, auth.uid(), now())
  on conflict (match_id, user_id) do update set last_read_at = now();
end $$;

-- Unread messages per match for the signed-in member (only matches that
-- have any).
create or replace function public.my_unread()
returns table (match_id uuid, unread int)
language sql stable security definer set search_path = public as $$
  select m.id, count(x.id)::int
    from public.matches m
    left join public.match_reads r on r.match_id = m.id and r.user_id = auth.uid()
    join public.messages x on x.match_id = m.id and x.sender <> auth.uid()
         and x.created_at > coalesce(r.last_read_at, '-infinity'::timestamptz)
   where auth.uid() in (m.user_a, m.user_b)
   group by m.id
$$;

revoke all on function public.mark_read(uuid) from public, anon;
revoke all on function public.my_unread() from public, anon;
grant execute on function public.mark_read(uuid) to authenticated;
grant execute on function public.my_unread() to authenticated;

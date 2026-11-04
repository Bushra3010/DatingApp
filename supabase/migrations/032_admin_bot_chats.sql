-- 032_admin_bot_chats.sql
-- Real-time bot conversation feed, manual operator replies, and auto-reply pause.

create table if not exists public.bot_stopped (
  match_id uuid primary key references public.matches (id) on delete cascade,
  stopped_at timestamptz not null default now()
);

create table if not exists public.bot_pending_replies (
  match_id uuid primary key references public.matches (id) on delete cascade,
  bot_id uuid not null references public.profiles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reply_body text not null,
  scheduled_at timestamptz not null default now()
);

-- 1. admin_bot_conversations: List all active conversations involving a bot
create or replace function public.admin_bot_conversations(p_bot_id uuid default null)
returns table (
  match_id uuid,
  bot_id uuid,
  bot_name text,
  bot_city text,
  bot_photo text,
  bot_job text,
  user_id uuid,
  user_name text,
  user_city text,
  user_photo text,
  user_age int,
  last_message text,
  last_message_at timestamptz,
  last_sender uuid,
  is_last_from_user boolean,
  is_paused boolean,
  pending_reply text,
  message_count bigint,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('bots');

  return query
  with match_bots as (
    select
      m.id as m_id,
      m.created_at as m_created_at,
      case when pa.is_bot then pa.id else pb.id end as b_id,
      case when pa.is_bot then pb.id else pa.id end as u_id
    from public.matches m
    join public.profiles pa on pa.id = m.user_a
    join public.profiles pb on pb.id = m.user_b
    where (pa.is_bot or pb.is_bot)
      and not (pa.is_bot and pb.is_bot)
      and (p_bot_id is null or pa.id = p_bot_id or pb.id = p_bot_id)
  ),
  msg_stats as (
    select
      msg.match_id,
      count(*) as total_msgs,
      (array_agg(msg.body order by msg.created_at desc))[1] as latest_body,
      max(msg.created_at) as latest_at,
      (array_agg(msg.sender order by msg.created_at desc))[1] as latest_sender
    from public.messages msg
    group by msg.match_id
  )
  select
    mb.m_id as match_id,
    bot.id as bot_id,
    coalesce(bot.name, 'Bot') as bot_name,
    coalesce(bot.city, '') as bot_city,
    coalesce(bot.photos[1], '') as bot_photo,
    coalesce(bot.job, '') as bot_job,
    usr.id as user_id,
    coalesce(usr.name, 'Member') as user_name,
    coalesce(usr.city, '') as user_city,
    coalesce(usr.photos[1], '') as user_photo,
    usr.age as user_age,
    ms.latest_body as last_message,
    ms.latest_at as last_message_at,
    ms.latest_sender as last_sender,
    (ms.latest_sender is not null and ms.latest_sender = usr.id) as is_last_from_user,
    exists (select 1 from public.bot_stopped bs where bs.match_id = mb.m_id) as is_paused,
    (select bpr.reply_body from public.bot_pending_replies bpr where bpr.match_id = mb.m_id limit 1) as pending_reply,
    coalesce(ms.total_msgs, 0) as message_count,
    mb.m_created_at as created_at
  from match_bots mb
  join public.profiles bot on bot.id = mb.b_id
  join public.profiles usr on usr.id = mb.u_id
  left join msg_stats ms on ms.match_id = mb.m_id
  order by coalesce(ms.latest_at, mb.m_created_at) desc;
end $$;

-- 2. admin_bot_messages: Thread history for a bot match
create or replace function public.admin_bot_messages(p_match_id uuid)
returns table (
  id uuid,
  match_id uuid,
  sender uuid,
  body text,
  created_at timestamptz,
  is_bot boolean,
  sender_name text
)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('bots');

  return query
  select
    msg.id,
    msg.match_id,
    msg.sender,
    msg.body,
    msg.created_at,
    p.is_bot,
    coalesce(p.name, case when p.is_bot then 'Bot' else 'Member' end) as sender_name
  from public.messages msg
  join public.profiles p on p.id = msg.sender
  where msg.match_id = p_match_id
  order by msg.created_at asc;
end $$;

-- 3. admin_send_bot_reply: Operator sends a manual message as the bot
create or replace function public.admin_send_bot_reply(p_match_id uuid, p_body text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_bot_id uuid;
  v_bot_name text;
  v_user_id uuid;
  v_msg_id uuid;
  v_msg_created_at timestamptz;
  v_clean text := trim(p_body);
begin
  perform public.require_admin('bots');

  if v_clean is null or char_length(v_clean) < 1 then
    raise exception 'Message body cannot be empty';
  end if;

  -- Find the bot in this match
  select
    case when pa.is_bot then pa.id else pb.id end,
    case when pa.is_bot then pa.name else pb.name end,
    case when pa.is_bot then pb.id else pa.id end
  into v_bot_id, v_bot_name, v_user_id
  from public.matches m
  join public.profiles pa on pa.id = m.user_a
  join public.profiles pb on pb.id = m.user_b
  where m.id = p_match_id and (pa.is_bot or pb.is_bot);

  if v_bot_id is null then
    raise exception 'No bot profile found in match %', p_match_id;
  end if;

  -- Insert message as bot
  insert into public.messages (match_id, sender, body)
  values (p_match_id, v_bot_id, v_clean)
  returning id, created_at into v_msg_id, v_msg_created_at;

  -- Pause automated replies for this conversation thread
  insert into public.bot_stopped (match_id)
  values (p_match_id)
  on conflict do nothing;

  delete from public.bot_pending_replies
  where match_id = p_match_id;

  -- Audit log
  insert into public.admin_audit (admin_id, action, target, details)
  values (
    auth.uid(),
    'bot_manual_reply',
    p_match_id::text,
    jsonb_build_object('bot_id', v_bot_id, 'bot_name', v_bot_name, 'user_id', v_user_id, 'preview', left(v_clean, 50))
  );

  return jsonb_build_object(
    'id', v_msg_id,
    'match_id', p_match_id,
    'sender', v_bot_id,
    'sender_name', v_bot_name,
    'body', v_clean,
    'created_at', v_msg_created_at,
    'is_bot', true,
    'is_paused', true
  );
end $$;

-- 4. admin_toggle_bot_pause: Pause or resume bot auto-replies for a match
create or replace function public.admin_toggle_bot_pause(p_match_id uuid, p_paused boolean)
returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');

  if p_paused then
    insert into public.bot_stopped (match_id)
    values (p_match_id)
    on conflict do nothing;

    delete from public.bot_pending_replies
    where match_id = p_match_id;
  else
    delete from public.bot_stopped
    where match_id = p_match_id;
  end if;

  insert into public.admin_audit (admin_id, action, target, details)
  values (
    auth.uid(),
    case when p_paused then 'bot_pause' else 'bot_resume' end,
    p_match_id::text,
    jsonb_build_object('paused', p_paused)
  );

  return p_paused;
end $$;

revoke all on function public.admin_bot_conversations(uuid) from public, anon;
revoke all on function public.admin_bot_messages(uuid) from public, anon;
revoke all on function public.admin_send_bot_reply(uuid, text) from public, anon;
revoke all on function public.admin_toggle_bot_pause(uuid, boolean) from public, anon;

grant execute on function public.admin_bot_conversations(uuid) to authenticated;
grant execute on function public.admin_bot_messages(uuid) to authenticated;
grant execute on function public.admin_send_bot_reply(uuid, text) to authenticated;
grant execute on function public.admin_toggle_bot_pause(uuid, boolean) to authenticated;

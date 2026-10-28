-- Everlane bot generator: make bots in bulk from a few settings, number them
-- (BOT-00019), group each run into a batch (B-001) that can be undone, and
-- act on many bots at once from the Bots list. Bots stay test accounts, so
-- their likes only ever reach other test accounts (see visible_to_me in 007).

create sequence if not exists public.bot_code_seq;
create sequence if not exists public.bot_batch_seq;

alter table public.profiles
  add column if not exists bot_code int,
  add column if not exists bot_batch text not null default '';

-- Number the bots made before this migration, oldest first.
update public.profiles p set bot_code = n.code
  from (select id, row_number() over (order by updated_at)::int code
          from public.profiles where is_bot and bot_code is null) n
 where p.id = n.id;
select setval('public.bot_code_seq', greatest((select max(bot_code) from public.profiles), 1),
              (select max(bot_code) from public.profiles) is not null);

-- Hand-made bots get a number too.
create or replace function public.number_new_bot()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_bot and new.bot_code is null then
    new.bot_code := nextval('public.bot_code_seq');
  end if;
  return new;
end $$;
drop trigger if exists profiles_number_bot on public.profiles;
create trigger profiles_number_bot before insert or update of is_bot on public.profiles
  for each row execute function public.number_new_bot();

-- Members can't set these: keep them as they were.
create or replace function public.keep_bot_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.admin_can('bots') then
    if tg_op = 'INSERT' then
      new.bot_code := null;
      new.bot_batch := '';
    else
      new.bot_code := old.bot_code;
      new.bot_batch := old.bot_batch;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_keep_bot_fields on public.profiles;
create trigger profiles_keep_bot_fields before insert or update on public.profiles
  for each row execute function public.keep_bot_fields();

-- Creates one bot per element of [rows] (the same fields as admin_save_bot,
-- plus "likes_test": true to have the bot like one test account), all in a
-- new batch. Returns the batch and the new bots' ids and numbers.
create or replace function public.admin_generate_bots(rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  batch text;
  r jsonb;
  bot uuid;
  made jsonb := '[]';
  target uuid;
begin
  perform public.require_admin('bots');
  if jsonb_typeof(rows) <> 'array' or jsonb_array_length(rows) not between 1 and 500 then
    raise exception 'between 1 and 500 bots at a time';
  end if;
  batch := 'B-' || lpad(nextval('public.bot_batch_seq')::text, 3, '0');
  for r in select * from jsonb_array_elements(rows) loop
    bot := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            created_at, updated_at, confirmation_token, recovery_token,
                            email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', bot, 'authenticated', 'authenticated',
            'bot-' || bot || '@bots.everlane.invalid', '', now(),
            '{"provider": "bot", "providers": []}', '{"bot": true}',
            now(), now(), '', '', '', '');
    insert into public.profiles (id, is_bot, is_test, onboarded, posted, bot_batch)
    values (bot, true, true, true, true, batch);
    perform public.apply_profile_fields(bot, r - 'likes_test');
    if coalesce((r->>'likes_test')::boolean, false) then
      select p.id into target from public.profiles p
       where p.is_test and not p.is_bot and p.onboarded
       order by random() limit 1;
      if target is not null then
        insert into public.likes (from_user, to_user) values (bot, target) on conflict do nothing;
      end if;
    end if;
    made := made || jsonb_build_object('id', bot,
      'code', (select bot_code from public.profiles where id = bot));
  end loop;
  perform public.log_admin('bots_generate', null,
                           jsonb_build_object('count', jsonb_array_length(rows), 'batch', batch));
  return jsonb_build_object('batch', batch, 'bots', made);
end $$;

-- Acts on many bots at once:
--   activate | pause          show or hide them in the app
--   city    value: "Pune"     move them to a city
--   fields  value: {id: {...}} set each bot's own fields (new bios, photos)
--   delete                    delete them; returns their photo paths so the
--                             panel can remove the files
create or replace function public.admin_bots_action(ids uuid[], action text, value jsonb default '{}')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  changed int := 0;
  paths text[];
  k text;
begin
  perform public.require_admin('bots');
  if exists (select 1 from unnest(ids) i
              where not exists (select 1 from public.profiles where id = i and is_bot)) then
    raise exception 'not a bot';
  end if;
  if action in ('activate', 'pause') then
    update public.profiles
       set blocked = action = 'pause',
           blocked_reason = case when action = 'pause' then 'Paused' else '' end,
           blocked_at = case when action = 'pause' then now() else null end
     where id = any (ids);
  elsif action = 'city' then
    update public.profiles set city = value #>> '{}', updated_at = now() where id = any (ids);
  elsif action = 'fields' then
    for k in select jsonb_object_keys(value) loop
      if k::uuid = any (ids) then perform public.apply_profile_fields(k::uuid, value->k); end if;
    end loop;
    update public.photo_reviews
       set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
     where user_id = any (ids) and status = 'pending';
  elsif action = 'delete' then
    select coalesce(array_agg(p), '{}') into paths
      from public.profiles, unnest(photos) p where id = any (ids);
    delete from auth.users where id = any (ids);
  else
    raise exception 'unknown action';
  end if;
  get diagnostics changed = row_count;
  if action = 'delete' then changed := cardinality(ids); end if;
  if action = 'fields' then changed := cardinality(ids); end if;
  perform public.log_admin('bots_' || action, null,
                           jsonb_build_object('count', changed) ||
                           case when action = 'city' then jsonb_build_object('city', value #>> '{}') else '{}' end);
  return jsonb_build_object('count', changed, 'photos', to_jsonb(coalesce(paths, '{}')));
end $$;

revoke all on function public.admin_generate_bots(jsonb) from public, anon;
grant execute on function public.admin_generate_bots(jsonb) to authenticated;
revoke all on function public.admin_bots_action(uuid[], text, jsonb) from public, anon;
grant execute on function public.admin_bots_action(uuid[], text, jsonb) to authenticated;

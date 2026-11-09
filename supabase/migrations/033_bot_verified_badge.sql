-- 033_bot_verified_badge.sql
-- Enables verified badge for bot profiles: individual toggle, bulk actions, and generator support.

-- 1. admin_toggle_bot_verified: Instantly verify or unverify a single bot
create or replace function public.admin_toggle_bot_verified(bot_id uuid, p_verified boolean)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('bots');
  
  if not exists (select 1 from public.profiles where id = bot_id and is_bot) then
    raise exception 'Not a bot profile';
  end if;

  update public.profiles
     set verified = p_verified,
         updated_at = now()
   where id = bot_id;

  perform public.log_admin(case when p_verified then 'bot_verify' else 'bot_unverify' end,
                           bot_id, jsonb_build_object('verified', p_verified));
  return p_verified;
end $$;

revoke all on function public.admin_toggle_bot_verified(uuid, boolean) from public, anon;
grant execute on function public.admin_toggle_bot_verified(uuid, boolean) to authenticated;

-- 2. Update apply_profile_fields to include verified column
create or replace function public.apply_profile_fields(target uuid, data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set
    name = coalesce(data->>'name', name),
    birthday = coalesce((data->>'birthday')::date, birthday),
    gender = coalesce(data->>'gender', gender),
    interested_in = coalesce(data->>'interested_in', interested_in),
    city = coalesce(data->>'city', city),
    job = coalesce(data->>'job', job),
    bio = coalesce(data->>'bio', bio),
    looking_for = coalesce(data->>'looking_for', looking_for),
    interests = case when jsonb_typeof(data->'interests') = 'array'
      then array(select jsonb_array_elements_text(data->'interests')) else interests end,
    prompt_label = coalesce(data->>'prompt_label', prompt_label),
    prompt_answer = coalesce(data->>'prompt_answer', prompt_answer),
    height_cm = case when data ? 'height_cm' then (data->>'height_cm')::int else height_cm end,
    languages = case when jsonb_typeof(data->'languages') = 'array'
      then array(select jsonb_array_elements_text(data->'languages')) else languages end,
    photos = case when jsonb_typeof(data->'photos') = 'array'
      then array(select jsonb_array_elements_text(data->'photos')) else photos end,
    quiz_answers = case when jsonb_typeof(data->'quiz_answers') = 'object'
      then data->'quiz_answers' else quiz_answers end,
    verified = case when data ? 'verified' then (data->>'verified')::boolean else verified end,
    updated_at = now()
  where id = target;
end $$;

revoke all on function public.apply_profile_fields(uuid, jsonb) from public, anon, authenticated;

-- 3. Update admin_save_bot to include verified column
create or replace function public.admin_save_bot(bot uuid, data jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  creating boolean := bot is null;
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  if creating then
    bot := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                            created_at, updated_at, confirmation_token, recovery_token,
                            email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', bot, 'authenticated', 'authenticated',
            'bot-' || bot || '@bots.everlane.invalid', '', now(),
            '{"provider": "bot", "providers": []}', '{"bot": true}',
            now(), now(), '', '', '', '');
    insert into public.profiles (id, is_bot, is_test, onboarded, posted, verified)
    values (bot, true, true, true, true, coalesce((data->>'verified')::boolean, false));
  elsif not exists (select 1 from public.profiles where id = bot and is_bot) then
    raise exception 'not a bot';
  end if;

  update public.profiles set
    name = coalesce(data->>'name', name),
    birthday = coalesce((data->>'birthday')::date, birthday),
    gender = coalesce(data->>'gender', gender),
    interested_in = coalesce(data->>'interested_in', interested_in),
    city = coalesce(data->>'city', city),
    job = coalesce(data->>'job', job),
    bio = coalesce(data->>'bio', bio),
    looking_for = coalesce(data->>'looking_for', looking_for),
    interests = coalesce(array(select jsonb_array_elements_text(data->'interests')), interests),
    prompt_label = coalesce(data->>'prompt_label', prompt_label),
    prompt_answer = coalesce(data->>'prompt_answer', prompt_answer),
    height_cm = case when data ? 'height_cm' then (data->>'height_cm')::int else height_cm end,
    languages = coalesce(array(select jsonb_array_elements_text(data->'languages')), languages),
    photos = coalesce(array(select jsonb_array_elements_text(data->'photos')), photos),
    verified = case when data ? 'verified' then (data->>'verified')::boolean else verified end,
    updated_at = now()
  where id = bot;

  update public.photo_reviews
     set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
   where user_id = bot and status = 'pending';

  perform public.log_admin(case when creating then 'bot_create' else 'bot_update' end,
                           bot, jsonb_build_object('name', data->>'name', 'verified', data->'verified'));
  return bot;
end $$;

-- 4. Update admin_bots_action to support 'verify' and 'unverify' bulk actions
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
  elsif action = 'verify' then
    update public.profiles set verified = true, updated_at = now() where id = any (ids);
  elsif action = 'unverify' then
    update public.profiles set verified = false, updated_at = now() where id = any (ids);
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
  if action in ('verify', 'unverify') then changed := cardinality(ids); end if;
  perform public.log_admin('bots_' || action, null,
                           jsonb_build_object('count', changed) ||
                           case when action = 'city' then jsonb_build_object('city', value #>> '{}') else '{}' end);
  return jsonb_build_object('count', changed, 'photos', to_jsonb(coalesce(paths, '{}')));
end $$;

revoke all on function public.admin_bots_action(uuid[], text, jsonb) from public, anon;
grant execute on function public.admin_bots_action(uuid[], text, jsonb) to authenticated;


-- Generated bots get interests and answers to the compatibility quiz, so
-- Chemistry works with them too.
--
-- 1. apply_profile_fields only changes the fields it is given. Before, a
--    later photos-only update (the bot generator's second step) emptied the
--    bot's interests and languages.
-- 2. profiles.quiz_answers stores each member's quiz answers
--    ({"q01": ["long_term"], ...}); members save their own, bots get random
--    ones. Other members read them through quiz_answers_of().

alter table public.profiles
  add column if not exists quiz_answers jsonb not null default '{}';

create or replace function public.apply_profile_fields(target uuid, data jsonb)
returns void language sql security definer set search_path = public as $$
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
    updated_at = now()
  where id = target
$$;
revoke all on function public.apply_profile_fields(uuid, jsonb) from public, anon, authenticated;

-- Random answers to every active quiz question: one option for
-- single-choice questions, 1 to max_choices (or 1 to 3 when unlimited)
-- for the others.
create or replace function public.random_quiz_answers()
returns jsonb language sql volatile set search_path = public as $$
  select coalesce(jsonb_object_agg(q.id, a.picked), '{}')
    from public.quiz_questions q
    cross join lateral (
      select jsonb_agg(o->'value') as picked
        from (select o from jsonb_array_elements(q.options) o order by random()
              limit case when q.max_choices = 1 then 1
                         else 1 + floor(random() * least(
                           case when q.max_choices > 0 then q.max_choices else 3 end,
                           jsonb_array_length(q.options)))::int end) s
    ) a
   where q.active and jsonb_array_length(q.options) > 0
$$;

-- 3 to 5 random interests from the admin's interest options.
create or replace function public.random_interests()
returns text[] language sql volatile set search_path = public as $$
  select coalesce(array_agg(value), '{}') from (
    select value from public.app_options
     where kind = 'interest' and active
     order by random() limit 3 + floor(random() * 3)::int) s
$$;
revoke all on function public.random_quiz_answers() from public, anon, authenticated;
revoke all on function public.random_interests() from public, anon, authenticated;

-- Every bot gets interests and quiz answers, whether the admin panel sent
-- them or not (and whichever way it was created).
create or replace function public.fill_bot_answers()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.is_bot then
    if cardinality(new.interests) = 0 then new.interests := public.random_interests(); end if;
    if cardinality(new.languages) = 0 then new.languages := array['English', 'Hindi']; end if;
    if new.quiz_answers = '{}' then new.quiz_answers := public.random_quiz_answers(); end if;
  end if;
  return new;
end $$;

drop trigger if exists profiles_fill_bot_answers on public.profiles;
create trigger profiles_fill_bot_answers before insert or update on public.profiles
  for each row execute function public.fill_bot_answers();

-- Fill the bots made so far.
update public.profiles set updated_at = updated_at where is_bot;

-- Quiz answers of members you can see, for Chemistry.
create or replace function public.quiz_answers_of(ids uuid[])
returns table (id uuid, quiz_answers jsonb)
language sql stable security definer set search_path = public as $$
  select p.id, p.quiz_answers from public.profiles p
   where p.id = any (ids) and p.id <> auth.uid()
     and public.visible_to_me(p) and p.quiz_answers <> '{}'
$$;
revoke all on function public.quiz_answers_of(uuid[]) from public, anon;
grant execute on function public.quiz_answers_of(uuid[]) to authenticated;

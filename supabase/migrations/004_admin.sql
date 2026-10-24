-- Everlane admin: admins, block/unblock, dynamic quiz questions and option
-- lists, and admin-only views of members (leads) and stats.

-- Who is an admin. Granted by user id, never by email: sign-up has no email
-- confirmation, so an email check could be claimed by anyone.
create table if not exists public.admins (
  user_id uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
-- No policies: only the security-definer functions below read it.

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;
grant execute on function public.is_admin() to authenticated;

-- Blocking.
alter table public.profiles
  add column if not exists blocked boolean not null default false,
  add column if not exists blocked_reason text not null default '',
  add column if not exists blocked_at timestamptz;

-- Members can upsert their own row, but never change their own block.
create or replace function public.keep_block_admin_only()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then
      new.blocked := false; new.blocked_reason := ''; new.blocked_at := null;
    else
      new.blocked := old.blocked;
      new.blocked_reason := old.blocked_reason;
      new.blocked_at := old.blocked_at;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_block_guard on public.profiles;
create trigger profiles_block_guard before insert or update on public.profiles
  for each row execute function public.keep_block_admin_only();

-- A blocked member can't like or message anyone.
create or replace function public.not_blocked()
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from public.profiles where id = auth.uid() and blocked)
$$;
grant execute on function public.not_blocked() to authenticated;

drop policy if exists "Send likes" on public.likes;
create policy "Send likes" on public.likes
  for insert to authenticated
  with check (from_user = auth.uid() and public.not_blocked());

drop policy if exists "Send match messages" on public.messages;
create policy "Send match messages" on public.messages
  for insert to authenticated with check (sender = auth.uid() and public.not_blocked() and exists (
    select 1 from public.matches m
    where m.id = match_id and auth.uid() in (m.user_a, m.user_b)));

-- Blocked members disappear from everyone's discovery, likes and matches.
create or replace function public.discover_members(max_results int default 50)
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[])
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages
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

create or replace function public.likes_received()
returns table (id uuid, name text, age int, gender text, city text, job text,
               bio text, looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[],
               target text, comment text, liked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages,
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

create or replace function public.my_matches()
returns table (match_id uuid, matched_at timestamptz, id uuid, name text,
               age int, gender text, city text, job text, bio text,
               looking_for text, interests text[], prompt_label text,
               prompt_answer text, photos text[], verified boolean,
               height_cm int, languages text[])
language sql stable security definer set search_path = public as $$
  select m.id, m.created_at, p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages
  from public.matches m
  join public.profiles p
    on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b) and not p.blocked
  order by m.created_at desc
$$;

-- Dynamic compatibility quiz.
create table if not exists public.quiz_questions (
  id text primary key,
  position int not null default 0,
  topic text not null default '',
  prompt text not null,
  section text not null default '',
  dimension text check (dimension in ('intentions', 'valuesBoundaries',
    'communication', 'lifestyle', 'personality', 'interests')),
  max_choices int not null default 1 check (max_choices >= 0),
  optional boolean not null default true,
  exclusive text[] not null default '{}',
  options jsonb not null default '[]',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.quiz_questions enable row level security;
drop policy if exists "Anyone reads active questions" on public.quiz_questions;
create policy "Anyone reads active questions" on public.quiz_questions
  for select to anon, authenticated using (active or public.is_admin());
drop policy if exists "Admins manage questions" on public.quiz_questions;
create policy "Admins manage questions" on public.quiz_questions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Option lists the app shows: interests, languages, prompts.
create table if not exists public.app_options (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('interest', 'language', 'prompt')),
  value text not null,
  position int not null default 0,
  active boolean not null default true,
  unique (kind, value)
);
alter table public.app_options enable row level security;
drop policy if exists "Anyone reads active options" on public.app_options;
create policy "Anyone reads active options" on public.app_options
  for select to anon, authenticated using (active or public.is_admin());
drop policy if exists "Admins manage options" on public.app_options;
create policy "Admins manage options" on public.app_options
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Admin views.
create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return jsonb_build_object(
    'accounts', (select count(*) from auth.users),
    'profiles', (select count(*) from public.profiles),
    'onboarded', (select count(*) from public.profiles where onboarded),
    'blocked', (select count(*) from public.profiles where blocked),
    'signups_today', (select count(*) from auth.users where created_at >= date_trunc('day', now())),
    'signups_7d', (select count(*) from auth.users where created_at >= now() - interval '7 days'),
    'likes', (select count(*) from public.likes),
    'matches', (select count(*) from public.matches),
    'messages', (select count(*) from public.messages));
end $$;

create or replace function public.admin_members()
returns table (id uuid, email text, phone text, joined_at timestamptz,
               last_sign_in_at timestamptz, provider text, name text, age int,
               gender text, interested_in text, city text, job text, bio text,
               looking_for text, height_cm int, languages text[],
               interests text[], photos text[], onboarded boolean,
               verified boolean, blocked boolean, blocked_reason text,
               likes_sent bigint, likes_received bigint, matches bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  return query
  select u.id, u.email::text, u.phone::text, u.created_at, u.last_sign_in_at,
         coalesce(u.raw_app_meta_data->>'provider', ''),
         coalesce(p.name, ''), coalesce(extract(year from age(p.birthday))::int, 0),
         coalesce(p.gender, ''), coalesce(p.interested_in, ''), coalesce(p.city, ''),
         coalesce(p.job, ''), coalesce(p.bio, ''), coalesce(p.looking_for, ''),
         p.height_cm, coalesce(p.languages, '{}'), coalesce(p.interests, '{}'),
         coalesce(p.photos, '{}'), coalesce(p.onboarded, false),
         coalesce(p.verified, false), coalesce(p.blocked, false),
         coalesce(p.blocked_reason, ''),
         (select count(*) from public.likes l where l.from_user = u.id),
         (select count(*) from public.likes l where l.to_user = u.id),
         (select count(*) from public.matches m where u.id in (m.user_a, m.user_b))
  from auth.users u
  left join public.profiles p on p.id = u.id
  order by u.created_at desc;
end $$;

create or replace function public.admin_set_blocked(member uuid, block boolean, reason text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not allowed'; end if;
  insert into public.profiles (id) values (member) on conflict (id) do nothing;
  update public.profiles
     set blocked = block,
         blocked_reason = case when block then coalesce(reason, '') else '' end,
         blocked_at = case when block then now() else null end
   where id = member;
end $$;

revoke all on function public.admin_stats() from public, anon;
revoke all on function public.admin_members() from public, anon;
revoke all on function public.admin_set_blocked(uuid, boolean, text) from public, anon;
grant execute on function public.admin_stats() to authenticated;
grant execute on function public.admin_members() to authenticated;
grant execute on function public.admin_set_blocked(uuid, boolean, text) to authenticated;

-- Seed the built-in quiz and option lists (only if empty).
insert into public.quiz_questions
  (id, position, topic, prompt, section, dimension, max_choices, optional, exclusive, options)
values
  ('q01', 1, 'Relationship direction', 'What are you ultimately hoping to build with the right person?', 'Relationship intentions', 'intentions', 1, true, '{}'::text[], '[{"value": "long_term", "label": "A long-term committed relationship"}, {"value": "marriage_family", "label": "Marriage and building a family"}, {"value": "meaningful_no_timeline", "label": "A meaningful relationship without a fixed timeline"}, {"value": "casual", "label": "Casual dating"}, {"value": "exploring", "label": "I’m still exploring"}]'::jsonb),
  ('q02', 2, 'Pace', 'How do you prefer a relationship to develop?', 'Relationship intentions', 'intentions', 1, true, '{}'::text[], '[{"value": "slow_trust", "label": "Slowly, building trust first"}, {"value": "natural", "label": "Naturally, without pressure"}, {"value": "intentional", "label": "Intentionally, with clear conversations about the future"}, {"value": "quick", "label": "Quickly, when the connection feels right"}]'::jsonb),
  ('q03', 3, 'Exclusivity', 'When would you prefer to discuss exclusivity?', 'Relationship intentions', 'intentions', 1, true, '{}'::text[], '[{"value": "early", "label": "Early, once we both feel interested"}, {"value": "few_dates", "label": "After a few dates"}, {"value": "know_better", "label": "When we know each other better"}, {"value": "naturally", "label": "When it comes up naturally"}]'::jsonb),
  ('q04', 4, 'Future plans', 'How important is it that your partner shares your long-term vision?', 'Relationship intentions', 'intentions', 1, true, '{}'::text[], '[{"value": "essential", "label": "Essential"}, {"value": "very_important", "label": "Very important, with room for compromise"}, {"value": "build_together", "label": "Important, but we can build a vision together"}, {"value": "unsure", "label": "I’m not sure about my future plans yet"}]'::jsonb),
  ('q05', 5, 'Everyday communication', 'What communication rhythm feels right to you?', 'Communication and emotional connection', 'communication', 1, true, '{}'::text[], '[{"value": "frequent", "label": "Frequent messages throughout the day"}, {"value": "few_meaningful", "label": "A few meaningful conversations"}, {"value": "calls_voice", "label": "Regular calls or voice notes"}, {"value": "flexible", "label": "Flexible, depending on each person’s day"}]'::jsonb),
  ('q06', 6, 'Showing affection', 'What makes you feel most loved?', 'Communication and emotional connection', 'communication', 2, true, '{}'::text[], '[{"value": "words", "label": "Words of appreciation"}, {"value": "quality_time", "label": "Quality time and undivided attention"}, {"value": "physical", "label": "Physical affection"}, {"value": "gestures_gifts", "label": "Thoughtful gestures and gifts"}, {"value": "practical_help", "label": "Practical help and support"}]'::jsonb),
  ('q07', 7, 'Difficult conversations', 'When something bothers you in a relationship, what do you usually prefer?', 'Communication and emotional connection', 'communication', 1, true, '{}'::text[], '[{"value": "talk_soon", "label": "Talk about it as soon as possible"}, {"value": "think_then_talk", "label": "Take some time to think, then talk"}, {"value": "gentle_message", "label": "Start with a gentle message"}, {"value": "both_ready", "label": "Wait until both people feel ready"}]'::jsonb),
  ('q08', 8, 'Emotional support', 'When you’re having a difficult day, what helps most?', 'Communication and emotional connection', 'communication', 1, true, '{}'::text[], '[{"value": "listen", "label": "Someone who listens without trying to fix things"}, {"value": "advice", "label": "Practical advice and solutions"}, {"value": "reassurance", "label": "Reassurance and affection"}, {"value": "space_then_connect", "label": "Space to process, followed by connection"}]'::jsonb),
  ('q09', 9, 'Core values', 'Which values matter most in a relationship?', 'Values and personality', 'valuesBoundaries', 3, true, '{}'::text[], '[{"value": "honesty", "label": "Honesty and transparency"}, {"value": "loyalty", "label": "Loyalty and commitment"}, {"value": "kindness", "label": "Kindness and empathy"}, {"value": "ambition", "label": "Ambition and personal growth"}, {"value": "independence", "label": "Independence and freedom"}, {"value": "family", "label": "Family and community"}, {"value": "curiosity", "label": "Curiosity and open-mindedness"}]'::jsonb),
  ('q10', 10, 'Decision-making', 'How do you usually make important decisions?', 'Values and personality', 'personality', 1, true, '{}'::text[], '[{"value": "think_carefully", "label": "I think carefully before deciding"}, {"value": "instincts", "label": "I trust my instincts"}, {"value": "talk_through", "label": "I talk things through with someone"}, {"value": "weigh_then_act", "label": "I weigh the options and then act"}]'::jsonb),
  ('q11', 11, 'Social energy', 'Your ideal weekend is usually…', 'Values and personality', 'personality', 1, true, '{}'::text[], '[{"value": "going_out", "label": "Going out, meeting people, and exploring"}, {"value": "staying_in", "label": "Staying in with someone I care about"}, {"value": "balance", "label": "A balance of social plans and quiet time"}, {"value": "spontaneous", "label": "Something spontaneous and unplanned"}]'::jsonb),
  ('q12', 12, 'Personal growth', 'How should a relationship support personal growth?', 'Values and personality', 'personality', 1, true, '{}'::text[], '[{"value": "motivate", "label": "We should actively motivate each other"}, {"value": "encourage_independence", "label": "We should encourage each other while respecting independence"}, {"value": "grow_naturally", "label": "We should grow naturally together"}, {"value": "comfort_stability", "label": "Emotional comfort and stability matter most to me"}]'::jsonb),
  ('q13', 13, 'Routine', 'Which lifestyle sounds most like yours?', 'Lifestyle and daily habits', 'lifestyle', 1, true, '{}'::text[], '[{"value": "structured", "label": "Structured and routine-oriented"}, {"value": "flexible_organized", "label": "Flexible, but reasonably organized"}, {"value": "spontaneous", "label": "Spontaneous and adventurous"}, {"value": "mix", "label": "A mix depending on work and life"}]'::jsonb),
  ('q14', 14, 'Work and ambition', 'How would you like work and ambition to fit into your relationship?', 'Lifestyle and daily habits', 'lifestyle', 1, true, '{}'::text[], '[{"value": "both_ambitious", "label": "We both prioritize ambitious goals"}, {"value": "support_different", "label": "We support each other’s different ambitions"}, {"value": "balance_first", "label": "Work-life balance comes first"}, {"value": "depends", "label": "It depends on our circumstances"}]'::jsonb),
  ('q15', 15, 'Money mindset', 'Which best describes your approach to money?', 'Lifestyle and daily habits', 'lifestyle', 1, true, '{}'::text[], '[{"value": "save_plan", "label": "Save, plan, and prioritize financial stability"}, {"value": "balance", "label": "Balance saving with enjoying life"}, {"value": "experiences", "label": "Prefer flexibility and experiences"}, {"value": "developing", "label": "Still developing my financial habits"}]'::jsonb),
  ('q16', 16, 'Time together', 'How much time would you ideally like to spend together?', 'Lifestyle and daily habits', 'lifestyle', 1, true, '{}'::text[], '[{"value": "lots", "label": "Lots of shared time and activities"}, {"value": "regular_quality", "label": "Regular quality time alongside independent lives"}, {"value": "flexible", "label": "A flexible balance that changes week to week"}, {"value": "independent", "label": "Plenty of independence, with meaningful time together"}]'::jsonb),
  ('q17', 17, 'Shared interests', 'What would you most enjoy doing together?', 'Interests and dating style', 'interests', 3, true, '{}'::text[], '[{"value": "travel", "label": "Travel and exploring new places"}, {"value": "food", "label": "Cooking, cafés, and discovering food"}, {"value": "entertainment", "label": "Movies, music, and entertainment"}, {"value": "fitness", "label": "Fitness, sports, and outdoor activities"}, {"value": "gaming", "label": "Gaming and technology"}, {"value": "culture", "label": "Art, books, and culture"}, {"value": "learning", "label": "Learning new skills or building projects"}, {"value": "staying_in", "label": "Staying in and relaxing together"}]'::jsonb),
  ('q18', 18, 'First date', 'Which first date would make you feel most comfortable?', 'Interests and dating style', 'interests', 1, true, '{}'::text[], '[{"value": "coffee", "label": "Coffee or a casual conversation"}, {"value": "dinner", "label": "Dinner in a nice place"}, {"value": "activity", "label": "An activity that gives us something to do"}, {"value": "walk", "label": "A walk in a public place"}, {"value": "group", "label": "A group activity or double date"}]'::jsonb),
  ('q19', 19, 'Adventure', 'How do you feel about trying new things with a partner?', 'Interests and dating style', 'interests', 1, true, '{}'::text[], '[{"value": "love_new", "label": "I love trying new things regularly"}, {"value": "open_comfortable", "label": "I’m open to them when we both feel comfortable"}, {"value": "familiar", "label": "I prefer familiar activities most of the time"}, {"value": "depends", "label": "It depends on the activity"}]'::jsonb),
  ('q20', 20, 'Personal space', 'How much independence do you need in a relationship?', 'Boundaries and relationship expectations', 'valuesBoundaries', 1, true, '{}'::text[], '[{"value": "a_lot", "label": "A lot; we should maintain our own routines and interests"}, {"value": "balance", "label": "A healthy balance of togetherness and independence"}, {"value": "share_most", "label": "I prefer sharing most parts of everyday life"}, {"value": "depends_stage", "label": "It depends on the stage of the relationship"}]'::jsonb),
  ('q21', 21, 'Reassurance', 'How do you feel about expressing your need for reassurance?', 'Boundaries and relationship expectations', 'valuesBoundaries', 1, true, '{}'::text[], '[{"value": "openly", "label": "I communicate it openly"}, {"value": "through_actions", "label": "I prefer reassurance through consistent actions"}, {"value": "working_on_it", "label": "It can be difficult, but I’m working on it"}, {"value": "little_needed", "label": "I generally feel comfortable without much reassurance"}]'::jsonb),
  ('q22', 22, 'Conflict repair', 'After a disagreement, what matters most to you?', 'Boundaries and relationship expectations', 'valuesBoundaries', 1, true, '{}'::text[], '[{"value": "honest_resolution", "label": "An honest conversation and a clear resolution"}, {"value": "heard", "label": "Feeling heard and understood"}, {"value": "apology_change", "label": "An apology followed by changed behaviour"}, {"value": "cool_off", "label": "Time to cool off before reconnecting"}]'::jsonb),
  ('q23', 23, 'Family involvement', 'How do you see family involvement in a long-term relationship?', 'Boundaries and relationship expectations', 'valuesBoundaries', 1, true, '{}'::text[], '[{"value": "closely_involved", "label": "Family should be closely involved in major decisions"}, {"value": "couple_decides", "label": "Family matters, but the couple makes its own decisions"}, {"value": "strong_boundaries", "label": "I prefer strong boundaries between family and relationship"}, {"value": "depends", "label": "It depends on the situation and culture"}]'::jsonb),
  ('q24', 24, 'Dealbreakers', 'Which relationship expectations are non-negotiable for you?', 'Boundaries and relationship expectations', 'valuesBoundaries', 0, true, '{none_or_later}'::text[], '[{"value": "honesty_fidelity", "label": "Honesty and fidelity"}, {"value": "shared_intentions", "label": "Shared intentions for the relationship"}, {"value": "boundaries", "label": "Respect for personal boundaries"}, {"value": "children_family", "label": "Similar views on children and family"}, {"value": "lifestyle_substances", "label": "Compatible lifestyle or substance-use preferences"}, {"value": "cultural_religious", "label": "Respect for cultural or religious values"}, {"value": "none_or_later", "label": "None selected / I’d rather discuss these later"}]'::jsonb)
on conflict (id) do nothing;

insert into public.app_options (kind, value, position)
values
  ('interest', 'Travel', 1),
  ('interest', 'Coffee', 2),
  ('interest', 'Music', 3),
  ('interest', 'Cooking', 4),
  ('interest', 'Fitness', 5),
  ('interest', 'Art', 6),
  ('interest', 'Books', 7),
  ('interest', 'Movies', 8),
  ('interest', 'Hiking', 9),
  ('interest', 'Dancing', 10),
  ('interest', 'Photography', 11),
  ('interest', 'Pets', 12),
  ('language', 'English', 1),
  ('language', 'Hindi', 2),
  ('language', 'Kannada', 3),
  ('language', 'Tamil', 4),
  ('language', 'Telugu', 5),
  ('language', 'Malayalam', 6),
  ('language', 'Marathi', 7),
  ('language', 'Bengali', 8),
  ('language', 'Gujarati', 9),
  ('language', 'Punjabi', 10),
  ('language', 'Urdu', 11),
  ('prompt', 'My ideal Sunday is', 1),
  ('prompt', 'I’m happiest when', 2),
  ('prompt', 'Ask me about', 3)
on conflict (kind, value) do nothing;

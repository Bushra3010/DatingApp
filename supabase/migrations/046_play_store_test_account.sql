-- 046_play_store_test_account.sql
-- Activates test login accounts for Google Play Store review and user testing.

-- 1. Confirm emails so Supabase Auth allows direct login without waiting for email verification
update auth.users
set email_confirmed_at = now()
where email in ('reviewer@everlanedating.com', 'testuser@everlanedating.com');

-- 2. Fully-onboarded profile for reviewer@everlanedating.com
insert into public.profiles (
  id, name, date_of_birth, gender, interested_in, height_cm,
  languages, city, bio, looking_for, interests, photos,
  onboarded, posted, is_bot, is_test
)
values (
  '7591b932-9952-4cff-ac46-1e76f15ffb8e',
  'Aarav',
  '1998-06-15',
  'Man',
  'Women',
  178,
  array['English', 'Hindi'],
  'Bengaluru',
  'Exploring the city, specialty coffee, indie music and weekend cycling.',
  array['Long-term relationship'],
  array['Coffee', 'Books', 'Music', 'Travel', 'Cycling'],
  array['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800'],
  true,
  true,
  false,
  true
)
on conflict (id) do update set
  name = excluded.name,
  onboarded = true,
  posted = true,
  photos = excluded.photos;

-- 3. Fully-onboarded profile for testuser@everlanedating.com
insert into public.profiles (
  id, name, date_of_birth, gender, interested_in, height_cm,
  languages, city, bio, looking_for, interests, photos,
  onboarded, posted, is_bot, is_test
)
values (
  'f39a8be3-e0d1-4a2c-9475-656560052b2c',
  'Kabir',
  '1997-04-20',
  'Man',
  'Women',
  180,
  array['English', 'Hindi'],
  'Bengaluru',
  'Passionate about design, photography, and good conversations over tea.',
  array['Long-term relationship'],
  array['Photography', 'Design', 'Tea', 'Art'],
  array['https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800'],
  true,
  true,
  false,
  true
)
on conflict (id) do update set
  name = excluded.name,
  onboarded = true,
  posted = true,
  photos = excluded.photos;

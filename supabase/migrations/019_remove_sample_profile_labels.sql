-- 019_remove_sample_profile_labels.sql
-- Removes the "Sample profile" label/badge from bot profiles and makes bot auto-replies natural without mentioning "sample profile".

-- Return empty so the app does not mark any profile as a sample profile.
create or replace function public.sample_profile_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where false
$$;

-- Update bot replies so they sound natural and don't include sample profile disclaimers.
create or replace function public.bot_reply_text(bot public.profiles, incoming text, opening boolean)
returns text language plpgsql volatile set search_path = public as $$
declare
  m text := lower(coalesce(incoming, ''));
  name text := coalesce(nullif(bot.name, ''), 'there');
  job text := coalesce(nullif(bot.job, ''), 'something I love');
  city text := coalesce(nullif(bot.city, ''), 'the city');
  hobby text := coalesce(bot.interests[1 + floor(random() * greatest(cardinality(bot.interests), 1))::int], 'good coffee');
  pick text[];
begin
  if opening and m = '' then
    pick := array[
      format('Hey! I’m %s 👋 Thanks for the like! What brought you to Everlane?', name),
      format('Hi, I’m %s! 😊 Great to connect with you. What’s your idea of a perfect weekend?', name),
      format('Hello! %s here ✨ Thanks for saying hi. Tell me something fun about you!', name)];
  elsif m ~ '(meet|date|coffee|drink|dinner|number|whatsapp|insta|instagram|call me|phone|address)' then
    pick := array[
      'That’s sweet of you! I prefer getting to know each other a bit more on chat first. How’s your week going? 💜',
      'Haha, let’s chat a bit more here first! What are you up to this weekend? 😊'];
  elsif m ~ '(how are you|how r u|how’s it going|how is it going|kaise ho|kese ho|kya haal)' then
    pick := array[
      'I’m doing great, thanks for asking! 😄 How’s your day going?',
      'All good here! Busy week, but in a good way. How about you?',
      'Pretty good! Just had a long day. What’s been the best part of yours?'];
  elsif m ~ '(what do you do|your job|work|kaam|profession|occupation)' then
    pick := array[
      format('I’m a %s. Honestly it keeps me busy, but I love it. What do you do?', job),
      format('%s, mostly! It has its moments 😅 What about you?', initcap(job))];
  elsif m ~ '(where|which city|kaha|kahan|from)' then
    pick := array[
      format('I’m around %s. Do you live nearby?', city),
      format('%s! Still discovering new places here. Any favourite spots?', city)];
  elsif m ~ '(hobby|hobbies|free time|weekend|fun|interest|like to do)' then
    pick := array[
      format('Mostly %s 😊 What do you love doing when you’re free?', lower(hobby)),
      format('Weekends are for %s for me. What’s yours?', lower(hobby))];
  elsif m ~ '\m(hi+|hello|hey+|hola|namaste|yo|hii)\M' then
    pick := array[
      format('Hey! 👋 Nice to hear from you. I’m %s. How’s your day going?', name),
      'Hi there! 😊 What’s keeping you busy these days?',
      'Hello! Glad you said hi. What made you swipe right?'];
  elsif m ~ '(thank|thanks|thx|shukriya)' then
    pick := array['Anytime! 😊', 'Of course! Tell me more about you.'];
  elsif position('?' in m) > 0 then
    pick := array[
      'Good question! 😄 I’d say it depends on the day. What do you think?',
      'Hmm, let me think… I’ll go with yes! What about you?',
      format('Honestly? %s is my answer to most things 😅 What’s yours?', initcap(hobby))];
  else
    pick := array[
      'Haha, I like that! Tell me more 😊',
      'That’s really interesting! What got you into that?',
      format('Love that. I’ve been into %s lately. What else should I know about you?', lower(hobby)),
      'Ooh, nice! What’s something you’re looking forward to this week?'];
  end if;
  return pick[1 + floor(random() * cardinality(pick))::int];
end $$;

revoke all on function public.bot_reply_text(public.profiles, text, boolean) from public, anon, authenticated;

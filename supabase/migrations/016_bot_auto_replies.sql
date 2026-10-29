-- Sample (bot) profiles chat back automatically.
--
-- When a member likes or messages a bot, the bot likes back (making a
-- match) and says hello; a message sent from Discover becomes the first
-- message of the chat and gets an answer. Every later message to a bot gets
-- an automatic reply. Bots are labelled "Sample profile" in the app, and
-- never agree to meet in person or ask for contact details.

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
      format('Hey! I’m %s 👋 Thanks for the like. Quick heads-up: I’m a sample profile, so my replies are automatic. What brought you to Everlane?', name),
      format('Hi, I’m %s! 😊 I’m one of Everlane’s sample profiles, so I answer automatically, but say hi anyway. What’s your idea of a perfect weekend?', name),
      format('Hello! %s here ✨ Just so you know, I’m a sample profile with automatic replies. Tell me something fun about you!', name)];
  elsif m ~ '(meet|date|coffee|drink|dinner|number|whatsapp|insta|instagram|call me|phone|address)' then
    pick := array[
      'That’s sweet of you! I’m a sample profile though, so I can’t meet or share contact details. Real members on Everlane can, so keep exploring Discover 💜',
      'Ha, I wish! I’m just a sample profile with automatic replies, so no real-life plans from me. Plenty of real people here would love that, though!'];
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

-- A like (or Discover message) to a bot: the bot likes back, which makes a
-- match, then the chat starts.
create or replace function public.bot_accept_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  bot public.profiles;
  mid uuid;
begin
  select * into bot from public.profiles where id = new.to_user and is_bot and not blocked;
  if not found then return new; end if;
  if exists (select 1 from public.profiles where id = new.from_user and is_bot) then
    return new;
  end if;
  insert into public.likes (from_user, to_user, target)
  values (new.to_user, new.from_user, 'profile') on conflict do nothing;
  select id into mid from public.matches
   where user_a = least(new.from_user, new.to_user)
     and user_b = greatest(new.from_user, new.to_user);
  if mid is null then return new; end if;
  if coalesce(new.comment, '') <> '' then
    -- Their note becomes the first message; the reply trigger answers it.
    insert into public.messages (match_id, sender, body)
    values (mid, new.from_user, left(new.comment, 2000));
  else
    insert into public.messages (match_id, sender, body)
    values (mid, new.to_user, public.bot_reply_text(bot, '', true));
  end if;
  return new;
end $$;

drop trigger if exists likes_bot_accept on public.likes;
create trigger likes_bot_accept after insert on public.likes
  for each row execute function public.bot_accept_like();

-- Every message to a bot gets an automatic reply.
create or replace function public.bot_answer_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  other uuid;
  bot public.profiles;
begin
  if exists (select 1 from public.profiles where id = new.sender and is_bot) then
    return new;
  end if;
  select case when m.user_a = new.sender then m.user_b else m.user_a end
    into other from public.matches m where m.id = new.match_id;
  select * into bot from public.profiles where id = other and is_bot and not blocked;
  if not found then return new; end if;
  insert into public.messages (match_id, sender, body)
  values (new.match_id, other, public.bot_reply_text(bot, new.body, false));
  return new;
end $$;

drop trigger if exists messages_bot_answer on public.messages;
create trigger messages_bot_answer after insert on public.messages
  for each row execute function public.bot_answer_message();

revoke all on function public.bot_reply_text(public.profiles, text, boolean) from public, anon, authenticated;

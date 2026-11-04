-- 031_remove_bot_labels.sql
-- Removes the "Automated profile" / "Sample profile" label from bots.

-- Return empty so nothing is marked as a sample/automated profile.
create or replace function public.sample_profile_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.profiles where false
$$;

-- Update greeting and default templates so bot messages sound natural without "automated profile" disclaimers.
update public.bot_kb
set replies = jsonb_set(
  replies,
  '{English}',
  to_jsonb('Hey {name}! 👋 I’m {bot}. How’s your day going?
Hello {name}! {bot} here. What made you say hi?
Hi {name} 😊 I’m {bot}. What’s up?'::text)
)
where intent = 'greeting';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{Hinglish}',
  to_jsonb('Hey {name}! 👋 Main {bot} hoon. Aapka din kaisa ja raha hai?
Hello {name}! {bot} here. Batao, kya chal raha hai?'::text)
)
where intent = 'greeting';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{Hindi}',
  to_jsonb('नमस्ते {name}! 👋 मैं {bot} हूँ। आपका दिन कैसा जा रहा है?
हेलो {name}! मैं {bot}। बताइए, क्या चल रहा है?'::text)
)
where intent = 'greeting';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{Marathi}',
  to_jsonb('नमस्कार {name}! 👋 मी {bot}. तुझा दिवस कसा चाललाय?
हाय {name}! मी {bot}. सांग, काय चाललंय?'::text)
)
where intent = 'greeting';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{English}',
  to_jsonb('Haha, I like that! Tell me more 😊
That’s really interesting! What got you into that?
Ooh, nice! What’s something you’re looking forward to this week?'::text)
)
where intent = 'fallback';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{Hinglish}',
  to_jsonb('Haha, accha laga! Aur batao 😊
Interesting hai! Isme interest kaise hua?
Aur batao?'::text)
)
where intent = 'fallback';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{English}',
  to_jsonb('That’s kind, thank you 😊 What do you like doing on weekends?'::text)
)
where intent = 'compliment';

update public.bot_kb
set replies = jsonb_set(
  replies,
  '{Hinglish}',
  to_jsonb('Bahut pyaari baat kahi, shukriya 😊 Aap weekend pe kya karna pasand karte ho?'::text)
)
where intent = 'compliment';

update public.bot_settings
set handoff_text = jsonb_build_object(
  'English', 'I have to run right now! Catch you later 💜',
  'Hindi', 'मुझे अभी निकलना होगा! बाद में बात करते हैं 💜',
  'Hinglish', 'Mujhe abhi nikalna hoga! Baad mein baat karte hain 💜',
  'Marathi', 'मला आता निघावं लागेल! नंतर बोलू 💜'
)
where id = 1;


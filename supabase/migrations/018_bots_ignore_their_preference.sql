-- Sample (bot) profiles show to every member whose own preferences they
-- fit, whoever the bot itself "wants to meet". Before, a member without a
-- gender set (or the wrong one for the bot) saw only a handful of the bots.

CREATE OR REPLACE FUNCTION public.discover_members(max_results integer DEFAULT 50)
 RETURNS TABLE(id uuid, name text, age integer, gender text, city text, job text, bio text, looking_for text, interests text[], prompt_label text, prompt_answer text, photos text[], verified boolean, height_cm integer, languages text[], voice_prompt_label text, voice_path text, voice_seconds integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  where p.id <> me.id
    and p.onboarded and public.visible_to_me(p)
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
    and (p.is_bot or p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by coalesce(p.boosted_until > now(), false) desc, p.updated_at desc
  limit max_results
$function$;

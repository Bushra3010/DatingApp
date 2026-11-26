-- 049_honest_automated_profiles.sql
-- Automated (bot) profiles must never pass for real, verified people.
--  1. Bots can't carry the "Selfie verified" badge (undoes 033).
--  2. Staff can't type replies as a bot (undoes the manual takeover in 032).
-- Labels come back via sample_profile_ids() in 046.

-- 1. No verified badge on bots, whatever path tries to set it.
update public.profiles set verified = false, updated_at = now()
 where is_bot and verified;

create or replace function public.bots_never_verified()
returns trigger language plpgsql as $$
begin
  if new.is_bot then
    new.verified := false;
  end if;
  return new;
end $$;

drop trigger if exists bots_never_verified on public.profiles;
create trigger bots_never_verified
  before insert or update of verified, is_bot on public.profiles
  for each row execute function public.bots_never_verified();

create or replace function public.admin_toggle_bot_verified(bot_id uuid, p_verified boolean)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  raise exception 'Automated profiles cannot be verified';
end $$;

-- 2. No human replies sent as a bot.
create or replace function public.admin_send_bot_reply(p_match_id uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  raise exception 'Staff cannot reply as an automated profile';
end $$;

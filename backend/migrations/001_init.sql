-- Kindred initial schema: accounts, profiles, discovery, likes, matches, chat, safety.
-- Location uses plain lat/lng with a haversine query so it runs on embedded Postgres;
-- switch to a PostGIS geography column once production Postgres is provisioned.

CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone           text UNIQUE,
  status          text NOT NULL DEFAULT 'onboarding'
                  CHECK (status IN ('onboarding', 'active', 'paused', 'banned', 'deleted')),
  plan            text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'plus')),
  plan_expires_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_active_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);

-- Bans follow the phone number (and later the device), not just the account.
CREATE TABLE banned_identifiers (
  kind       text NOT NULL CHECK (kind IN ('phone', 'device')),
  value      text NOT NULL,
  reason     text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (kind, value)
);

CREATE TABLE otp_codes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone      text NOT NULL,
  code_hash  text NOT NULL,
  attempts   int NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX otp_codes_phone_idx ON otp_codes (phone, created_at DESC);

CREATE TABLE profiles (
  user_id             uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  first_name          text,
  birth_date          date,                -- locked once set (ON-2)
  gender              text,                -- woman | man | nonbinary
  show_me             text[] NOT NULL DEFAULT '{}',
  intent              text CHECK (intent IN ('long_term', 'long_term_open_short', 'figuring_out')),
  height_cm           smallint CHECK (height_cm BETWEEN 120 AND 230),
  lat                 double precision,
  lng                 double precision,
  city                text,
  -- Vitals (PR-4): { "work": { "value": "...", "visible": true }, ... }
  vitals              jsonb NOT NULL DEFAULT '{}'::jsonb,
  verification_status text NOT NULL DEFAULT 'none'
                      CHECK (verification_status IN ('none', 'pending', 'verified', 'rejected')),
  verification_media  text,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE preferences (
  user_id         uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  age_min         smallint NOT NULL DEFAULT 18 CHECK (age_min >= 18),
  age_max         smallint NOT NULL DEFAULT 99 CHECK (age_max <= 99),
  max_distance_km smallint NOT NULL DEFAULT 50 CHECK (max_distance_km BETWEEN 1 AND 500),
  CHECK (age_min <= age_max)
);

CREATE TABLE settings (
  user_id       uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  read_receipts boolean NOT NULL DEFAULT true,
  -- Push notification controls per type (PF-5).
  push          jsonb NOT NULL DEFAULT '{"likes": true, "matches": true, "messages": true, "reminders": true}'::jsonb
);

CREATE TABLE media (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('photo', 'video', 'voice', 'verification')),
  url        text NOT NULL,
  mime_type  text NOT NULL,
  size_bytes int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE photos (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  media_id          uuid NOT NULL REFERENCES media (id) ON DELETE CASCADE,
  position          smallint NOT NULL CHECK (position BETWEEN 0 AND 5),
  caption           text CHECK (char_length(caption) <= 100),
  moderation_status text NOT NULL DEFAULT 'pending'
                    CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  moderation_reason text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, position) DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE prompt_library (
  id        text PRIMARY KEY,
  category  text NOT NULL,
  text      text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE profile_prompts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  prompt_id  text NOT NULL REFERENCES prompt_library (id),
  answer     text NOT NULL CHECK (char_length(answer) BETWEEN 1 AND 225),
  position   smallint NOT NULL CHECK (position BETWEEN 0 AND 2),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, position) DEFERRABLE INITIALLY DEFERRED,
  UNIQUE (user_id, prompt_id)
);

CREATE TABLE likes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  to_user     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('photo', 'prompt')),
  target_id   uuid NOT NULL,
  comment     text CHECK (char_length(comment) <= 150),
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'matched', 'removed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (from_user <> to_user),
  UNIQUE (from_user, to_user)
);
CREATE INDEX likes_inbox_idx ON likes (to_user, status, created_at);
CREATE INDEX likes_sent_today_idx ON likes (from_user, created_at);

-- Skipped profiles can return later (DI-3): discovery hides a skip for a cool-down period.
CREATE TABLE skips (
  from_user  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  to_user    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (from_user, to_user)
);

CREATE TABLE matches (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  user_b        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  like_id       uuid REFERENCES likes (id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  unmatched_at  timestamptz,
  unmatched_by  uuid,
  CHECK (user_a < user_b),
  UNIQUE (user_a, user_b)
);
CREATE INDEX matches_user_b_idx ON matches (user_b);

CREATE TABLE messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id    uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('text', 'voice', 'gif', 'like_context')),
  body        text CHECK (char_length(body) <= 2000),
  media_url   text,
  duration_s  smallint CHECK (duration_s BETWEEN 1 AND 60),
  flagged     boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  read_at     timestamptz
);
CREATE INDEX messages_match_idx ON messages (match_id, created_at DESC);

CREATE TABLE blocks (
  blocker    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blocked    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker, blocked)
);
CREATE INDEX blocks_blocked_idx ON blocks (blocked);

CREATE TABLE reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  reported    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  reason      text NOT NULL,
  details     text CHECK (char_length(details) <= 1000),
  message_id  uuid REFERENCES messages (id) ON DELETE SET NULL,
  priority    text NOT NULL CHECK (priority IN ('high', 'normal')),
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'actioned', 'dismissed')),
  resolution  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX reports_queue_idx ON reports (status, priority, created_at);

CREATE TABLE subscriptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  store       text NOT NULL CHECK (store IN ('play', 'app_store', 'dev')),
  product_id  text NOT NULL,
  external_id text NOT NULL,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store, external_id)
);

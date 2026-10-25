# Everlane mobile

A Flutter UI for Everlane, with a reference-inspired white interface, rounded portrait cards, pastel actions, a profile drawer, and a separate bio and interests view. Likes on photos and prompts remain interactive. Android and iOS runners are included; the web runner is a convenient way to review the same mobile UI in a browser.

## Run

With Flutter on your PATH:

```bash
cd mobile
flutter pub get
flutter run                         # select an iOS simulator or Android device
flutter run -d chrome               # browser UI review
flutter analyze
flutter test
```

For this workspace, Flutter was downloaded to `/tmp/kindred-flutter-sdk`; use `/tmp/kindred-flutter-sdk/bin/flutter` if it is not installed on your PATH. This temporary SDK can be removed by the operating system; install a persistent SDK for ongoing development.

To serve a compiled browser preview:

```bash
flutter build web --no-web-resources-cdn
python3 tool/serve_preview.py  # http://127.0.0.1:8081; prevents stale UI caching
```

## Implemented preview

- Discover one person at a time, with photos, rare verification badges, a written prompt and photo prompts ("Ask about this photo", their soundtrack). Swipe right to like, left to pass, with a slow page-turn motion and light haptics.
- Like a specific photo, prompt or soundtrack, adding an optional 150-character comment. Rewind (undo the last pass) needs Plus.
- Profiles open with a shared-photo transition and parallax, show what the person is looking for, and can carry a voice prompt drawn as a waveform (animated only; no audio files).
- Explore: browse people by what they're looking for (long-term, short-term fun, coffee date, date night, new friends, travel buddy), or answer five questions for an introduction.
- Hangouts (Platinum): set what you feel like doing, filter plans, request to join, message the host or host your own plan.
- Membership: the four launch tiers from the membership options doc (Free ₹0, Plus ₹249, Gold ₹499, Platinum ₹899 a month; test prices). Daily like limits per plan, Rewind and the intention filter with Plus, Likes You and monthly boosts with Gold, the detailed Chemistry report and Hangouts with Platinum. Safety and privacy controls stay free. Choosing a plan changes it locally; no payment is taken.
- Onboarding (first launch) and the 24-question Everlane Compatibility Quiz, with a Chemistry card on each profile that follows the question bank's scoring rules: weighted areas, dealbreakers filtered first, intent mismatches never hidden, a preliminary view with too few answers.
- Privacy: distances show as "Nearby" or rounded, never exact; free Invisible mode setting.
- Voice prompts: pick a question and record up to 30 seconds (WAV), listen back, save, re-record or remove. They play on profiles.
- Explore: Nearby profiles, and Crossed paths, a map of ~1 km areas where you and someone else were on the same day. Sharing your area is opt-in; only the rounded area and the day are stored, and turning it off deletes them. Map tiles come from OpenStreetMap, which is for light use only; move to a paid tile provider before launch.
- Preferences: search a specific city (distance then doesn't apply).
- Chat: day separators and a time on each message; tap the name to open the profile.
- Settings: Delete account (needs migration 006).
- Moderation: reports go to the admin panel with the last five messages; warnings show on the You tab; suspended accounts can't sign in; banned words are refused.
- Light theme by default, with a Dark mode switch in Settings.
- Filter by age, distance and verified profiles; handle empty discovery and paused profiles.
- Accept or remove incoming likes (Gold or Platinum); accepting opens a conversation.
- Browse conversations and send local text messages; blank messages are ignored.
- Edit your first name, work and prompt with validation.
- Preview pause and notification preferences; report, block and unmatch flows hide local profiles/conversations. Reporting explicitly states that no moderation report is submitted.
- Keyboard-aware sheets, accessible button labels, scrollable screens, image fallback and phone-width layout on desktop.

## Boundaries

This is a **demo-data UI**, not an authenticated client. All state is held in memory and resets when the app restarts. No like, comment, message, preference or report is sent to the NestJS backend. Notifications are not delivered. No accounts, purchases or real-world matches are created; plan changes, Hangout requests and dark mode reset on reload. The eight-like allowance is per preview session, not a production daily counter.

The next integration work is OTP/onboarding, authenticated API repositories using the existing backend, media uploads, persistent sessions, realtime chat and server error/loading states. Platform app icons and signing still use Flutter development defaults. Native release builds have not been verified.

## Files

- `lib/theme.dart`: palette, typography and component styles.
- `lib/models.dart`: typed demo models and shared preview state.
- `lib/widgets.dart`: portraits, tags, empty states, buttons and sheets.
- `lib/screens.dart`: discovery, Explore, likes, messages, chat, profile, membership and supporting flows.
- `lib/hangouts.dart`: Hangouts setup, plan list and hosting.
- `lib/introductions.dart`: the five-question introduction quiz.
- `lib/question_bank.dart`: onboarding and compatibility questions with stable IDs and answer values.
- `lib/chemistry.dart`: Chemistry scoring and demo quiz answers.
- `lib/onboarding.dart`: onboarding, the compatibility quiz and the Chemistry card.
- `lib/main.dart`: application and navigation shell.
- `test/`: filter/like/match invariants and phone-width interaction checks.

See `assets/README.md` for image and font provenance. All names, profiles and conversations are fictional.

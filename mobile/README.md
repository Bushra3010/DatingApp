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
- Hangouts (Premium): set what you feel like doing, filter plans, request to join, message the host or host your own plan.
- Membership: Free, Plus and Premium from PRD §7. Choosing a plan changes it locally; no payment is taken. Free members see incoming likes blurred.
- Privacy: distances show as "Nearby" or rounded, never exact; Invisible mode setting (Plus).
- Light theme by default, with a Dark mode switch in Settings.
- Filter by age, distance and verified profiles; handle empty discovery and paused profiles.
- Accept or remove incoming likes (Plus or Premium); accepting opens a conversation.
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
- `lib/main.dart`: application and navigation shell.
- `test/`: filter/like/match invariants and phone-width interaction checks.

See `assets/README.md` for image and font provenance. All names, profiles and conversations are fictional.

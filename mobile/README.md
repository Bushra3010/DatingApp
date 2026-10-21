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
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

## Implemented preview

- Discover one person at a time, with photos, verification badges, vitals and a written prompt.
- Like a specific photo or prompt, adding an optional 150-character comment; pass and undo a pass.
- Filter by age, distance and verified profiles; handle empty discovery and paused profiles.
- Accept or remove incoming likes; accepting opens a conversation.
- Browse conversations and send local text messages; blank messages are ignored.
- Edit your first name, work and prompt with validation.
- Preview pause and notification preferences; report, block and unmatch flows hide local profiles/conversations. Reporting explicitly states that no moderation report is submitted.
- Keyboard-aware sheets, accessible button labels, scrollable screens, image fallback and phone-width layout on desktop.

## Boundaries

This is a **demo-data UI**, not an authenticated client. All state is held in memory and resets when the app restarts. No like, comment, message, preference or report is sent to the NestJS backend. Notifications are not delivered. No accounts, purchases or real-world matches are created. The eight-like allowance is per preview session, not a production daily counter.

The next integration work is OTP/onboarding, authenticated API repositories using the existing backend, media uploads, persistent sessions, realtime chat and server error/loading states. Platform app icons and signing still use Flutter development defaults. Native release builds have not been verified.

## Files

- `lib/theme.dart`: palette, typography and component styles.
- `lib/models.dart`: typed demo models and shared preview state.
- `lib/widgets.dart`: portraits, tags, empty states, buttons and sheets.
- `lib/screens.dart`: discovery, likes, messages, chat, profile and supporting flows.
- `lib/main.dart`: application and navigation shell.
- `test/`: filter/like/match invariants and phone-width interaction checks.

See `assets/README.md` for image and font provenance. All names, profiles and conversations are fictional.

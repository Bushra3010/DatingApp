# Everlane

A relationship-first dating app for Android and iOS (working name). Product spec: [PRD-Hinge-Style-Dating-App.md](PRD-Hinge-Style-Dating-App.md).

| Folder | What | Status |
| --- | --- | --- |
| `backend/` | NestJS API + realtime chat (PRD §8) | MVP P0 API built, 23 e2e tests passing |
| `mobile/` | Flutter app for Android and iOS | Interactive UI preview: Discover, Likes, Messages, Profile |
| admin console | Moderation UI over `/admin/*` | Not started; API exists |

## Preview the UI

The [Flutter mobile app](mobile/README.md) has an interactive demo for Discover, Likes You, Messages, and Profile. It uses in-memory fictional data and does not yet call the API.

```bash
cd mobile
flutter pub get
flutter run -d chrome  # review the mobile UI in a browser
flutter run            # use an Android device or iOS simulator
```

Flutter stable is installed at `~/development/flutter`. Use `~/development/flutter/bin/flutter` if Flutter is not on your PATH.

## Run the backend

```bash
cd backend
pnpm install
cp .env.example .env
pnpm seed          # 10 demo profiles around Bengaluru (log in with code 000000)
pnpm build && pnpm start   # http://localhost:3000
pnpm test          # end-to-end tests against an in-memory database
```

No Docker or Postgres is needed locally. With `DATABASE_URL` unset, the API uses embedded Postgres (PGlite) stored in `backend/.data/`. In production, set `DATABASE_URL` to a real Postgres instance.

In dev, OTP codes are printed to the server log, and `000000` is accepted. Photos and selfie verification are auto-approved. `NODE_ENV=production` refuses to start with any of these dev shortcuts on.

## API (all JSON; bearer token from `/auth/otp/verify`)

| Area | Endpoints | PRD |
| --- | --- | --- |
| Auth | `POST /auth/otp/request`, `POST /auth/otp/verify` | ON-1 |
| Profile | `GET /me`, `PATCH /me/basics`, `PATCH /me/vitals`, `PUT/DELETE /me/photos/:pos`, `POST /me/photos/reorder`, `GET /prompts`, `PUT/DELETE /me/prompts/:pos`, `GET /me/preview`, `POST /me/verification` | ON-2–5, PR-1/2/4/6 |
| Media | `POST /media/{photo,video,voice,verification}` (multipart `file`) | PR-1, CH-2 |
| Discovery | `GET /discover?limit=` | DI-1, §6 phase 1 |
| Likes | `POST /likes`, `GET /likes/remaining`, `POST /skips/:userId`, `GET /likes/received?sort=`, `POST /likes/:id/match`, `POST /likes/:id/remove` | DI-2–4, LM-1–3 |
| Chat | `GET /matches`, `GET/POST /matches/:id/messages`, `POST /matches/:id/read`, `POST /matches/:id/unmatch` | CH-1/2/5 |
| Realtime | socket.io `/realtime`, `auth: { token }`; events `like:new`, `match:new`, `match:removed`, `message:new`, `message:read`, `typing` | CH-1 |
| Safety | `POST/DELETE /blocks/:userId`, `POST /reports` | §5 |
| Account | `GET/PATCH /me/preferences`, `GET/PATCH /me/settings`, `POST /me/pause`, `POST /me/unpause`, `GET /me/export`, `DELETE /me` | ON-6, PF-1, PF-5 |
| Billing | `GET /billing/plans`, `POST /billing/verify` | §7 |
| Admin | `/admin/reports`, `/admin/photos/pending`, `/admin/verifications/pending`, `/admin/users/:id/ban`, `/admin/purge-deleted` (header `x-admin-token`) | §5 |

## What is stubbed (provider interfaces are in place)

- **SMS:** logs to the console. Plug an SMS gateway into `SmsProvider`.
- **Photo moderation and selfie face-match:** `auto` or `manual`. Plug a vendor API into `moderation.providers.ts`.
- **Push:** `Notifier` respects per-type settings but doesn't deliver yet (FCM/APNs to come).
- **Billing:** only the `dev` store grants Plus. Google Play and App Store receipt verification and renewal webhooks are still to do.
- **Storage:** local disk under `/media`. S3 + CDN for production.
- **Location:** a haversine query over lat/lng. Move to PostGIS when production Postgres is provisioned.
- **Realtime fan-out:** an in-process event bus. Use the Redis adapter once more than one API instance runs.

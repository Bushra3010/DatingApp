# Everlane — Google Play release kit

Everything Play Console asks for, in the order it asks.

## Files

| What | File |
| --- | --- |
| App bundle (upload this to Play) | `play-store/everlane-1.0.0-13.aab` (not in git) |
| APK (to install on a phone and test) | `play-store/everlane-1.0.0-13.apk` (not in git) |
| App icon 512×512 | `play-store/icon-512.png` |
| Feature graphic 1024×500 | `play-store/feature-graphic-1024x500.png` |
| Phone screenshots (2–8, take them from the APK) | see "Screenshots" below |

Build both with the Play flag (the Play build doesn't sell plans, see "Payments"):

```bash
cd mobile
flutter build appbundle --release --dart-define=PLAY_STORE=true
flutter build apk --release --dart-define=PLAY_STORE=true
```

Raise `version:` in `mobile/pubspec.yaml` (the number after `+`) for every upload.

## Signing key — back this up

- Upload keystore: `~/everlane-android-keys/upload-keystore.jks` (alias `upload`)
- Passwords: `~/everlane-android-keys/key.properties` (copied to `mobile/android/key.properties`, which git ignores)
- Upload key SHA-1: `0F:85:BF:28:D7:28:F0:17:5F:F8:59:38:7F:97:AE:8C:FC:3A:56:4E`
- Upload key SHA-256: `F0:63:2D:F5:BE:C6:AD:D2:BE:96:12:92:DF:C1:E6:22:F8:68:46:55:CC:C2:80:07:07:54:18:0D:73:9C:C6:4E`

Copy the whole `~/everlane-android-keys` folder somewhere safe (password manager / encrypted drive).
With Play App Signing (the default) a lost upload key can be reset through Play support, but it takes days.

## Create the app

- App name: **Everlane: Dating & Hangouts**
- Default language: English (India) – en-IN
- App or game: App · Free
- Package name: `com.everlane.everlane`

## Store listing

**Short description (80 max)**

> Meet people nearby, check your chemistry and join Hangouts plans in your city.

**Full description**

> Everlane is a dating app for adults in India who want something real.
>
> • Discover people near you, sorted by distance, with filters for age, intent, lifestyle and more.
> • Chemistry quiz: answer a few questions and see how well you match, area by area.
> • Hangouts: host or join small plans nearby — coffee, a walk, a gig — and meet in public places.
> • Verified badges: a quick live selfie shows a profile is really them.
> • Voice prompts, interests and prompts that show who you are, not just how you look.
> • Safety first: block and report from any profile or chat, and our team reviews every report.
>
> Some profiles on Everlane are automated profiles we create; they are clearly labelled "Automated profile" in the app and are not real people.
>
> Everlane is for people aged 18 and over.
>
> Privacy Policy: https://www.everlanedating.com/privacy.html
> Terms: https://www.everlanedating.com/terms.html

- App category: **Dating**
- Contact email: preetsoni7847@gmail.com (the Grievance Officer email; change if you have a support address)
- Website: https://www.everlanedating.com
- Privacy Policy URL: **https://www.everlanedating.com/privacy.html**

## Screenshots

Install the APK on a phone, sign in, and take 4–6 screenshots (Discover card, profile details, Chemistry, Hangouts, Messages, Filters).
Play needs at least 2 phone screenshots, 1080×1920 or similar (9:16), PNG or JPEG.
Don't show real members' faces without their permission — use your own or test accounts.

## App content (Policy → App content)

| Section | Answer |
| --- | --- |
| Privacy policy | https://www.everlanedating.com/privacy.html |
| Ads | No, the app has no ads |
| App access | Restricted — give reviewers a test account (email + password) that is onboarded, with a photo. Create it yourself; don't use a real member's account. |
| Content rating | Fill the IARC questionnaire: category "Social / Communication". Answer **Yes** to: users can interact/communicate, users can share location (Hangouts/distance), users can share user-generated content (photos). No violence, no gambling, no purchases of digital goods in the Play build. Dating apps normally come out **18+ / Adults only** in India. |
| Target audience | 18 and over only |
| News app | No |
| COVID-19 app | No |
| Data safety | See below |
| Government app | No |
| Financial features | None |
| Health | No |
| Account deletion | In-app: Menu → Settings → Delete account. Web link: **https://www.everlanedating.com/delete-account.html** |

## Data safety

Data is encrypted in transit: **Yes**. Users can request deletion: **Yes**. Data is not sold and not shared with third parties for advertising.

| Data type | Collected | Shared | Purpose | Optional? |
| --- | --- | --- | --- | --- |
| Name | Yes | No | App functionality, Account management | Required |
| Email address | Yes | No | Account management | Required (email or Google sign-in) |
| Phone number | Yes | No | Account management | Optional (phone sign-in) |
| User IDs | Yes | No | App functionality, Account management | Required |
| Approximate location | Yes | No | App functionality (distance, Hangouts) | Optional |
| Precise location | No (rounded to ~1 km before saving) | | | |
| Date of birth / Gender / Sexual orientation ("Other info" + "Sexual orientation") | Yes | No | App functionality | Required |
| Photos | Yes | No | App functionality (profile, verification selfie) | Required |
| Voice or sound recordings | Yes | No | App functionality (voice prompt) | Optional |
| Other in-app messages | Yes | No | App functionality | Required |
| Other user-generated content (bio, prompts, quiz answers, Hangouts) | Yes | No | App functionality | Required |
| Purchase history | Yes (plans bought on the website) | No | App functionality | Optional |
| App interactions (likes, passes, matches) | Yes | No | App functionality, Personalisation | Required |

"Shared" means sent to another company for its own use; Supabase and Vercel are service providers, which Play doesn't count as sharing.

## Payments (important)

Google Play's Payments policy requires Play Billing for digital subscriptions sold inside an Android app.
Manual UPI to a UPI ID for Plus/Gold/Platinum is not allowed in a Play app and gets apps rejected or removed.

So the Play build (`--dart-define=PLAY_STORE=true`) doesn't sell plans: paid plans show "Not available in the app", with no UPI sheet and no link to the website.
Members who bought a plan on everlanedating.com keep it in the Android app.
The website keeps UPI as it is.
To sell inside the Android app later, add Google Play Billing (in_app_purchase) — that's a separate piece of work.

## Before you press "Send for review"

- [ ] Play Console developer account (one-time US$25) — create it yourself.
- [ ] Upload the `.aab` to **Internal testing** first, install from the Play link, and test sign-in (email and Google), photos, location, chat, Hangouts.
- [ ] Google sign-in on Android: in Google Cloud → Credentials, add an **Android** OAuth client for package `com.everlane.everlane` with the **App signing key SHA-1 from Play Console** (Setup → App signing), plus the upload key SHA-1 above.
- [ ] New personal developer accounts must run a **closed test with at least 12 testers for 14 days** before production access.
- [ ] Have a lawyer review the Terms and Privacy Policy (company name and address are still missing).

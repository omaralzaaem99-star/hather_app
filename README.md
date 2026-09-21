# حاضر

Flutter delivery application with user and captain flows.

## Tech Stack

- Flutter
- Dart
- Supabase (Auth, Database, Edge Functions)
- Firebase Cloud Messaging

## Requirements

- Flutter 3.38.4 (or compatible with Dart SDK `^3.10.3`)
- Dart 3.10.3
- Android SDK
- JDK 17
- macOS + Xcode for iOS builds
- CocoaPods (iOS)

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Create local environment file:

```bash
cp env.example .env
```

3. Configure `.env` (local only — never commit real values):

```
USE_FAKE_AUTH=false
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
```

4. Firebase

- Android: place `android/app/google-services.json`
- iOS: place `ios/Runner/GoogleService-Info.plist`
- Keep `lib/firebase_options.dart` aligned with the same Firebase project

5. Run:

```bash
flutter run
```

## Android

- Package: `com.hather.hatherios`
- Requires `google-services.json`
- For release builds, configure signing via `android/key.properties` (see `android/key.properties.example`)
- Do not commit keystores or `key.properties`

## iOS

- Bundle ID: `com.hather.hatherios`
- Requires `GoogleService-Info.plist`
- From `ios/`:

```bash
pod install
open Runner.xcworkspace
```

- Configure Xcode Team / signing
- Enable Push Notifications and Background Modes → Remote notifications
- Configure APNs in Apple Developer and Firebase Console

## Supabase

Project layout:

- `supabase/migrations/` — versioned migrations for CLI deploy
- `supabase/sql/` — full SQL archive / operator scripts (includes historical and manual scripts)
- `supabase/functions/` — Edge Functions

Server-side secret **names** (set in Supabase project secrets, never in the app):

- `SUPABASE_SERVICE_ROLE_KEY`
- `OTPIQ_API_KEY` (or legacy `OTPIQ_API_TOKEN`)
- `SEND_SMS_HOOK_SECRET` (Auth SMS hook)
- `FIREBASE_SERVICE_ACCOUNT_JSON` (push dispatch)
- `BUNNY_STORAGE_ZONE` / `BUNNY_STORAGE_API_KEY` / `BUNNY_CDN_HOSTNAME` (home ads images)

Note: `supabase/sql/` contains manual development cleanup scripts marked:

`MANUAL / DEVELOPMENT CLEANUP SCRIPT — DO NOT RUN ON PRODUCTION WITHOUT REVIEW`

Migration note: two files share timestamp prefix `20250902160000_*` under `supabase/migrations/`. Do not rename casually if already applied to a live project.

## Security

- Keep `.env` out of version control and delivery ZIP archives
- Never place service role keys, OTPIQ keys, Bunny keys, Firebase service accounts, or keystore passwords in source
- Client configs (`SUPABASE_URL`, publishable key, Firebase client options) are expected for the app to run

## Tests

```bash
flutter test
flutter analyze
```

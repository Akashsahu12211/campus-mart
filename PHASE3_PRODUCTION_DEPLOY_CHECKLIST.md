# Phase 3 Production Deploy Checklist

This checklist is for the final production hardening of Campus Mart web, backend, and Flutter after Phase 3.

## 1. Web Environment

- Create `frontend/.env.production` from `frontend/.env.example`
- Set:
  - `REACT_APP_API_URL`
  - `REACT_APP_WS_URL`
  - `REACT_APP_FIREBASE_API_KEY`
  - `REACT_APP_FIREBASE_AUTH_DOMAIN`
  - `REACT_APP_FIREBASE_PROJECT_ID`
  - `REACT_APP_FIREBASE_STORAGE_BUCKET`
  - `REACT_APP_FIREBASE_MESSAGING_SENDER_ID`
  - `REACT_APP_FIREBASE_APP_ID`
  - `REACT_APP_FIREBASE_MEASUREMENT_ID`
  - `REACT_APP_FIREBASE_VAPID_KEY`
  - `REACT_APP_SUPPORT_EMAIL`
  - `REACT_APP_SUPPORT_BUSINESS_EMAIL`
  - `REACT_APP_SUPPORT_WHATSAPP_NUMBER`
  - `REACT_APP_SOCIAL_INSTAGRAM`
  - `REACT_APP_SOCIAL_LINKEDIN`
  - `REACT_APP_SOCIAL_YOUTUBE`
  - `REACT_APP_SOCIAL_X`
  - `REACT_APP_SOCIAL_GITHUB`

## 2. Firebase Social Auth

- Enable `Google` provider in Firebase Auth
- Enable `Facebook` provider in Firebase Auth
- Add deployed web domain to Firebase Authorized Domains
- Configure Facebook App ID and App Secret in Firebase
- Confirm frontend Firebase project matches backend Firebase Admin project

## 3. Backend Production

- Provide Firebase Admin credentials securely
- Do not commit `backend/src/main/resources/firebase-key.json`
- Verify JWT, mail, DB, and payment secrets are production values
- Verify CORS origins match deployed domains
- Run `mvn -q -DskipTests compile`

## 4. Flutter Android Release

- Create `campus_mart_app/android/key.properties` from `android/key.properties.example`
- Add release keystore at the configured path
- Verify `google-services.json` belongs to the production Firebase project
- Add release SHA-1 and SHA-256 to Firebase project settings
- Complete Facebook Android app setup if using Facebook login in release
- Test:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter build apk --release`
  - or `flutter build appbundle --release`

## 5. Flutter Runtime Defines

- Pass support values during release builds:
  - `--dart-define=SUPPORT_EMAIL=support@your-domain.com`
  - `--dart-define=SUPPORT_BUSINESS_EMAIL=business@your-domain.com`
  - `--dart-define=SUPPORT_WHATSAPP_NUMBER=91XXXXXXXXXX`
- Optional social link values:
  - `--dart-define=SOCIAL_INSTAGRAM=https://instagram.com/yourhandle`
  - `--dart-define=SOCIAL_LINKEDIN=https://linkedin.com/company/yourcompany`
  - `--dart-define=SOCIAL_YOUTUBE=https://youtube.com/@yourchannel`
  - `--dart-define=SOCIAL_X=https://x.com/yourhandle`
  - `--dart-define=SOCIAL_GITHUB=https://github.com/yourorg`

## 6. Functional QA

- Email/password login works
- Google login works
- Facebook login works
- Item share works on web and Flutter
- Activity history loads correctly
- Language and location save in settings
- `Near Me` filter works
- Admin advanced analytics load
- Legal pages open correctly

## 7. Go-Live Safety

- Backup production database
- Verify support inbox access
- Verify WhatsApp support number is active
- Verify push notifications in release environment
- Smoke test admin flows after deploy

## 8. Final Signoff

- Web build passes
- Backend compile passes
- Flutter analyze passes within accepted warning threshold
- Release artifact generated successfully

# Production Launch Checklist

Ye checklist staging se public launch tak ke final steps ko cover karti hai. Goal hai ki real creds aane par minimum last-minute surprises ho.

## 1. Required Launch Credentials

Backend / Infra:
- `DB_USERNAME`
- `DB_PASSWORD`
- production MySQL URL via `spring.datasource.url`
- `JWT_SECRET`
- `JWT_EXPIRY_MS`
- `JWT_REFRESH_EXPIRY_MS`

Payments:
- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`

Phone OTP:
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`

Email:
- `MAIL_USERNAME`
- `MAIL_PASSWORD`
- `NOTIFICATIONS_FROM_EMAIL`

Push:
- `FIREBASE_SERVICE_ACCOUNT_PATH`
- Android `google-services.json` regenerated for final release package ID
- Web Firebase production config values in `frontend/.env`

Domains / CORS:
- `APP_FRONTEND_BASE_URL`
- `APP_CORS_ALLOWED_ORIGINS`
- `APP_WEBSOCKET_ALLOWED_ORIGINS`
- `APP_UPLOADS_PUBLIC_BASE_URL`
- `REACT_APP_API_URL`
- `REACT_APP_WS_URL`

Object storage / CDN:
- `APP_STORAGE_MODE`
- `APP_STORAGE_S3_BUCKET`
- `APP_STORAGE_S3_REGION`
- `APP_STORAGE_S3_ENDPOINT`
- `APP_STORAGE_S3_ACCESS_KEY`
- `APP_STORAGE_S3_SECRET_KEY`
- `APP_STORAGE_S3_PUBLIC_BASE_URL`
- `APP_STORAGE_S3_KEY_PREFIX`
- `APP_STORAGE_S3_PATH_STYLE`

Optional scale infra:
- `APP_WEBSOCKET_BROKER_RELAY_HOST`
- `APP_WEBSOCKET_BROKER_RELAY_PORT`
- `APP_WEBSOCKET_BROKER_RELAY_LOGIN`
- `APP_WEBSOCKET_BROKER_RELAY_PASSCODE`
- `APP_WEBSOCKET_BROKER_RELAY_VHOST`

Flutter release:
- `APP_ANDROID_APPLICATION_ID`
- `android/key.properties`
- release keystore file

## 2. Production Env Defaults

Ye values production me force honi chahiye:
- `APP_ENV=production`
- `APP_EXPOSE_DEV_OTP=false`
- `APP_ENFORCE_CONTACT_ACCESS_GATING=true`
- `APP_ALLOW_TEST_PLAN_ACTIVATION=false`
- `APP_DETAILED_ERRORS=false`
- `APP_REQUIRE_SECURE_TRANSPORT=true`
- `FLYWAY_ENABLED=true`
- `NOTIFICATIONS_NEW_ITEM_EMAIL_BROADCAST_ENABLED=false`
- `APP_STORAGE_MODE=s3`

## 3. Storage / Uploads

- `APP_STORAGE_MODE=s3` use karo for public launch
- `APP_UPLOADS_BASE_DIR` sirf development/local fallback ke liye use karo
- `APP_UPLOADS_PUBLIC_BASE_URL` ko deployed backend domain par set karo if any backend-hosted assets remain
- CDN ya reverse proxy se `/uploads/**` cache headers add karo
- Large image cleanup/retention policy define karo

## 4. Pre-Launch Verification

Backend:
```powershell
cd C:\Users\HP\All_Projects\campus-mart-v2\backend
mvn test -q
mvn -q -DskipTests package
```

Frontend:
```powershell
cd C:\Users\HP\All_Projects\campus-mart-v2\frontend
npm run build
```

Flutter:
```powershell
cd C:\Users\HP\All_Projects\campus_mart_flutter\campus_mart_app
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --release --dart-define=CAMPUS_MART_API_URL=https://api.mycampusmart.in/api --dart-define=APP_ANDROID_APPLICATION_ID=in.mycampusmart.app
```

Smoke:
- `GET /api/public/health` => `UP`
- `GET /api/public/ready` => `UP`
- register flow with real email + phone OTP
- create listing with image upload
- chat room open + message send
- payment order create + webhook verify
- admin login + reports/support visibility

## 5. Infrastructure Expectations

- backend HTTPS ke peeche run ho
- web Vercel/static hosting par ho
- DB automated backup enabled ho
- logs persistent destination me collect ho
- websocket broker relay use karo if multi-instance chat deploy karna hai

## 6. Launch-Go Criteria

Public launch tabhi karo jab:
- all builds green ho
- real creds validated ho
- payment webhook end-to-end pass ho
- OTP end-to-end pass ho
- uploads public URLs se render ho rahe ho
- at least 1 closed-beta smoke pass ho on web + Android app
- release APK/AAB final package ID aur release signing ke saath successfully build ho

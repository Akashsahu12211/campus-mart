# Deploy Checklist

## Web

- Set `REACT_APP_API_URL` to your deployed backend API URL.
- Set `REACT_APP_WS_URL` to your deployed backend WebSocket URL.
- Set all Firebase web variables from `frontend/.env.example`.
- Run `npm install`
- Run `npm test`
- Run `npm run build`

## Backend

- Create `backend/.env` from `backend/.env.example`.
- Set `DB_USERNAME`, `DB_PASSWORD`, and `JWT_SECRET`.
- Set `APP_FRONTEND_BASE_URL` to your real frontend domain.
- Set `APP_CORS_ALLOWED_ORIGINS` to every allowed frontend origin.
- Set `MAIL_*`, `TWILIO_*`, `RAZORPAY_*`, and `FIREBASE_SERVICE_ACCOUNT_PATH` as needed.
- Run `mvn test`

## Flutter

- Keep `android/app/google-services.json` in place.
- Copy `android/key.properties.example` to `android/key.properties` and fill release keystore values.
- For release builds, pass a real backend URL:
  `--dart-define=CAMPUS_MART_API_URL=https://api.your-domain.com/api`
- Run `flutter test`
- Run `flutter build apk --release`

## Final Smoke Test

- Login and registration
- Item create, edit, delete
- Wishlist
- Reservations
- Chat
- Admin actions
- Notifications
- Payments

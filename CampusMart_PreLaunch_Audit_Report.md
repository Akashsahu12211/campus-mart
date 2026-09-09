# CampusMart Pre-Launch Audit Report

Audit date: 2026-05-20  
Project: CampusMart  
Frontend domain planned: `mycampusmart.in`  
Backend API domain planned: `api.mycampusmart.in`

## 1. Executive Summary

CampusMart is a student-to-student campus marketplace with web and Android app clients, a Spring Boot backend, MySQL persistence, Razorpay payments, JWT + OTP authentication, chat, wishlist, reviews, reports, admin tooling, notifications, support flows, and monetization scaffolding.

This is not a beginner prototype anymore. The codebase is feature-rich, builds successfully, and the core commerce loop exists end to end. The project is close to a real beta product. It is not fully safe for a public launch today because the remaining risk is concentrated in payload/storage hygiene, media URL integrity, operational hardening, and a few security/runtime gaps.

Strict verdict:
- Overall launch readiness: `81/100`
- Beta launch readiness: `90%`
- Public launch readiness: `78%`
- Risk level: `Medium`
- Final verdict: `Beta launch after fixes`

What I verified in this audit:
- `mvn test -q` passed
- `mvn -q -DskipTests package` passed
- `npm test -- --watchAll=false` passed
- `npm run build` passed
- `flutter test` passed
- `flutter analyze --no-fatal-infos --no-fatal-warnings` completed with `150` info-level issues, no blocking errors
- `flutter build apk --release` passed
- Local backend runtime smoke passed on `http://localhost:8081/api/public/health`
- Local items pagination runtime smoke passed on `http://localhost:8081/api/items/paginated`
- Local React root smoke passed on `http://localhost:3000`
- Local React dev-proxy API smoke passed on `http://localhost:3000/api/public/health` with JSON-style request headers

Most important launch blockers:
- Existing item media still points to `http://localhost:8081/uploads/...` in stored data, so existing listings will break after deployment if not migrated.
- User `profilePic` is still stored as `LONGTEXT` string data and can produce large payloads and storage abuse.
- Listing image normalization still accepts arbitrary `http://` and `https://` URLs, which is unsafe for a public marketplace.
- Public health/readiness endpoints expose internal operational details.
- Web auth tokens are still stored in `localStorage`, which increases XSS blast radius.
- The frontend repo-local `.env` still contains `DANGEROUSLY_DISABLE_HOST_CHECK=true`, which is not acceptable for a production deployment path.

## 2. Project Overview

### 2.1 What this project is

CampusMart is a multi-client campus commerce platform where students can:
- create accounts with email/phone OTP verification
- list used goods
- browse and search listings
- chat with sellers
- negotiate through offers
- pay through Razorpay
- confirm delivery or raise disputes
- leave reviews
- report content/users
- manage activity through user and admin dashboards

### 2.2 What problem it solves

It solves the fragmented, low-trust student resale problem:
- campus buying/selling is usually handled through WhatsApp, informal groups, or unstructured posts
- buyers lack trust, seller reputation, negotiation history, and transaction proof
- students need low-friction, local, category-based resale with campus-specific filters

### 2.3 Target users

Primary users:
- college students buying and selling second-hand goods
- student buyers looking for local pickup/reserved items
- student sellers managing listings, offers, payments, and reviews

Secondary users:
- admins/moderators
- support operators
- future institution-level expansion users

### 2.4 How the web app works

The React app provides the full marketplace UI:
- public browsing and listing discovery
- login/register/OTP/password reset
- item detail, wishlist, chat, orders, reservations
- listing create/edit flows with uploads
- admin pages
- support/legal/settings pages

Routing is managed in `frontend/src/App.js`. API access is centralized in `frontend/src/api/api.js`. Production URLs are resolved via `frontend/src/config/runtimeConfig.js`.

### 2.5 How the Flutter app works

The Flutter app mirrors most major flows:
- authentication
- browsing/search
- item creation/editing
- wishlist
- chat
- offers
- payment
- reviews
- notifications
- admin access
- support and site screens

It uses `provider`, `dio`, secure token storage, Firebase push wiring, and production API defaults in `lib/config/api_config.dart`.

### 2.6 How the backend works

The Spring Boot backend exposes REST APIs plus WebSocket chat endpoints. It handles:
- authentication and OTP sessions
- JWT access tokens and refresh sessions
- user profiles
- item lifecycle and uploads
- search/filter/pagination
- wishlist
- chat rooms and messages
- offers
- payment orders, verification, disputes, refunds
- reviews and reports
- notifications
- admin functions
- health/readiness endpoints

Architecture is mostly controller/service/repository separated and backed by MySQL with Flyway migrations.

### 2.7 How the systems communicate

Text architecture:

1. React web and Flutter app call Spring Boot APIs over HTTP/HTTPS.
2. Spring Boot reads/writes MySQL through JPA repositories and some native queries.
3. Chat uses Spring WebSocket/STOMP with a simple broker by default and optional broker relay config.
4. Payments go from client to backend to Razorpay order creation/verification/webhook validation.
5. Push notification registration goes from client to backend; backend uses Firebase Admin when configured.
6. Listing image uploads go from client to backend upload endpoints, then backend stores to local disk or S3-compatible storage depending on config.
7. Email OTP / system mail goes through configured SMTP.
8. Phone OTP flows are designed for Twilio-backed delivery but still support dev exposure when explicitly enabled.

### 2.8 Complete system flows

#### Registration flow

1. User submits name, email, phone, password.
2. Backend creates a registration session and sends email OTP and phone OTP.
3. User verifies email OTP.
4. User verifies phone OTP.
5. Backend completes the student account creation and returns access + refresh tokens.

Key code:
- `backend/src/main/java/com/campusmart/controller/AuthController.java`
- `backend/src/main/java/com/campusmart/service/OtpService.java`
- `frontend/src/pages/Register.js`
- `campus_mart_app/lib/screens/register_screen.dart`

#### Login flow

1. User submits email + password.
2. Backend validates credentials with hashed password check.
3. Backend returns short-lived access token, refresh token, and user payload.
4. Web stores tokens in `localStorage`; Flutter stores tokens via secure storage service.

Key code:
- `backend/src/main/java/com/campusmart/controller/AuthController.java`
- `backend/src/main/java/com/campusmart/config/JwtUtil.java`
- `frontend/src/api/api.js`
- `campus_mart_app/lib/services/api_service.dart`

#### OTP flow

1. OTP session is created with expiry.
2. Backend rate limits OTP-related endpoints.
3. OTP is sent through configured channel or exposed in dev mode when explicitly allowed.
4. Verification consumes the latest active OTP session.

#### Item listing flow

1. Authenticated seller opens add-item form.
2. Images are uploaded through dedicated upload API.
3. Item create/update request is sent as DTO-based payload.
4. Backend persists item metadata, image URLs, listing state, and review/rating data if provided.

#### Item search/browse flow

1. Public user loads home.
2. Frontend requests paginated items and categories.
3. Backend applies filters, sorting, and pagination.
4. Results include nested seller and media payloads.

#### Wishlist flow

1. Authenticated user toggles wishlist on an item.
2. Backend inserts/deletes wishlist pair.
3. Wishlist screen fetches saved items.

#### Chat flow

1. Buyer opens chat with seller from item page or inbox.
2. Frontend establishes STOMP/WebSocket connection.
3. Messages are sent via WebSocket, with HTTP fallback in web in some cases.
4. Backend persists messages and surfaces inbox summaries.
5. Flutter still includes periodic polling fallback for inbox refresh.

#### Offer flow

1. Buyer submits offer price against an item.
2. Seller accepts or rejects.
3. Accepted offer changes the payable amount logic used by payment order creation.

#### Payment flow

1. Buyer clicks pay on item or accepted offer.
2. Backend creates authoritative Razorpay order using server-side amount logic.
3. Client completes Razorpay checkout.
4. Backend verifies signature and records payment.
5. Buyer confirms delivery or raises dispute.
6. Seller release/refund/dispute actions are tracked.

#### Review/rating flow

1. Buyer submits review after transaction.
2. Backend persists rating and comment.
3. Item detail and seller reputation surfaces review data.

#### Report/moderation flow

1. User reports an item or user.
2. Backend persists report record.
3. Admin reviews and takes moderation action.

#### Admin flow

1. Admin logs in.
2. Admin dashboard loads metrics, moderation, logs, and payment visibility.
3. Admin actions run through role-protected endpoints.

#### Notification flow

1. User grants notification permission.
2. Web or app registers token with backend.
3. Backend stores notification token and emits inbox/email/push events when supported.
4. Firebase Admin must be configured for push delivery to actually work from backend.

## 3. System Architecture

### 3.1 High-level architecture

```text
React Web ───────┐
                 ├── HTTP/HTTPS ──> Spring Boot API ──> MySQL
Flutter App ─────┘                         │
                                           ├── Razorpay
                                           ├── Firebase Admin
                                           ├── SMTP Mail
                                           ├── Twilio OTP
                                           └── Local/S3 Asset Storage

React Web / Flutter App ── WebSocket/STOMP ──> Spring Boot Chat Layer
```

### 3.2 Storage and data model summary

Core entities:
- `students`
- `items`
- `item_images`
- `wishlist`
- `offers`
- `payment_orders`
- `reviews`
- `reports`
- `chat_rooms`
- `messages`
- `notifications`
- `refresh_token_sessions`
- `rate_limit_counters`
- `registration_sessions`
- `institutions`
- monetization tables such as subscriptions and commission ledgers

### 3.3 Architectural strengths

- Broad feature coverage across web and mobile
- Centralized API client layers
- Refresh token logic exists
- Flyway migrations exist
- Dockerfile exists for backend
- Release APK builds
- S3-compatible storage path exists
- Payment flow is now server-authoritative

### 3.4 Architectural weaknesses

- Existing production data still references local asset URLs
- Some API contracts still mix DTOs with raw maps
- Large binary-like payloads are still represented as strings
- Chat uses Spring simple broker by default, not a production relay
- Public operational endpoints expose more detail than needed

## 4. Feature Inventory

| Feature | Description | Backend | Web | Flutter | DB | APIs involved | Important files | Score /10 | Priority | Notes / issues |
|---|---|---|---|---|---|---|---|---:|---|---|
| Registration + OTP onboarding | Multi-step account creation with email and phone verification | Done | Done | Done | Done | `/api/auth/register`, `/verify-email`, `/verify-phone`, resend endpoints | `AuthController.java`, `OtpService.java`, `Register.js`, `register_screen.dart` | 8 | P0 | Good flow, but real Twilio/Firebase/mail creds still required for public launch |
| Login + refresh + logout | JWT access token + refresh session + logout/all | Done | Done | Done | Done | `/api/auth/login`, `/refresh`, `/logout`, `/logout-all` | `AuthController.java`, `JwtUtil.java`, `RefreshTokenUtil.java`, `src/api/api.js`, `api_service.dart` | 8 | P0 | Web uses `localStorage`; logout rollback issue observed once in logs |
| Forgot password / reset | Password reset with verification flow | Done | Partial | Partial | Done | forgot/reset auth endpoints | `AuthController.java`, auth pages/screens | 7 | P1 | Needs stronger QA coverage |
| User profile management | Update profile, avatar, bio, settings | Done | Done | Done | Partial | student/profile APIs | `StudentService.java`, `Profile.js`, Flutter profile screens | 6 | P0 | `profilePic` stored as `LONGTEXT`; payload bloat risk |
| Privacy/preferences/blocking | Privacy, block status, preferences | Partial | Partial | Partial | Partial | profile/block related APIs | `Student.java`, profile pages | 6 | P2 | Exists in model/flows, not fully polished |
| Item create/edit/delete | Listing lifecycle | Done | Done | Done | Done | `/api/items`, `/api/items/{id}`, related item actions | `ItemController.java`, `ItemService.java`, `AddItem.js`, `EditItem.js`, add/edit item screens | 8 | P0 | Core flow works |
| Item image upload | Listing image uploads and storage | Done | Done | Done | Done | upload endpoints + item save | `ItemImageStorageService.java`, `PublicAssetStorageService.java` | 6 | P0 | Existing data migration incomplete; external URL acceptance unsafe |
| Browse home feed | Home listings and categories | Done | Done | Done | Done | `/api/items/paginated`, `/api/categories` | `Home.js`, Flutter home screens, `ItemController.java` | 8 | P0 | Runtime smoke passed |
| Search | Keyword search | Done | Done | Done | Done | paginated items APIs | home/search components + service layer | 8 | P0 | Functional |
| Filters | Price, condition, hostel, branch, etc. | Done | Done | Done | Done | paginated items APIs | home/filter UIs + backend search logic | 7 | P1 | Multi-college normalization still partial |
| Sorting | Newest and other orderings | Done | Done | Done | Done | paginated items APIs | `Home.js`, Flutter home logic, item service | 8 | P1 | Works |
| Pagination | Paginated item listing | Done | Done | Done | Done | `/api/items/paginated` | `ItemController.java`, home pages | 8 | P0 | Verified on backend smoke |
| Wishlist | Save/remove items | Done | Done | Done | Done | wishlist endpoints | wishlist controllers/services/pages/screens | 8 | P1 | Good after integrity constraint work |
| Chat realtime | 1:1 buyer-seller messaging | Done | Done | Done | Done | WebSocket + chat REST endpoints | `ChatController.java`, `ChatService.java`, `ChatScreen.js`, Flutter chat screens | 7 | P0 | Works, but default broker and inbox polling are not ideal for scale |
| Chat inbox | Conversation list with unread counts | Done | Done | Done | Done | inbox endpoints | `MessageRepository.java`, `ChatService.java`, inbox pages/screens | 6 | P1 | N+1 unread count pattern remains |
| Offers / negotiation | Offer create/accept/reject | Done | Done | Done | Done | offer endpoints | `OfferController.java`, offer screens/pages | 7 | P0 | Core flow exists; input validation is still too loose |
| Orders / reservations | Buyer/seller order states and item reservation | Done | Done | Done | Done | order/payment/item endpoints | `PaymentController.java`, `MyOrders.js`, Flutter order screens | 8 | P0 | Strong user value |
| Razorpay payment order creation | Create payment order with server-side amount authority | Done | Done | Done | Done | `/api/payments/create-order` | `PaymentController.java`, `PaymentService.java`, web/app pay UI | 9 | P0 | Previously risky, now much stronger |
| Payment verification | Razorpay signature validation and order updates | Done | Done | Done | Done | verify + webhook endpoints | `PaymentService.java`, `PaymentController.java` | 8 | P0 | Good overall |
| Refund / dispute / delivery confirmation | Post-payment resolution | Done | Done | Done | Done | payment dispute/refund endpoints | payment controller/service, order screens | 8 | P0 | Should be smoke-tested with live credentials before launch |
| Reviews / ratings | Review item/seller after transaction | Done | Done | Done | Done | review endpoints | `ReviewController.java`, detail pages/screens | 7 | P1 | Update path lacks strong DTO validation |
| Report item/user | Abuse reporting | Done | Partial | Partial | Done | report endpoints | `ReportController.java`, item detail actions | 7 | P0 | Backend exists; UX needs stricter QA |
| Admin dashboard | Moderation, metrics, logs, payments | Done | Done | Done | Done | admin endpoints | `AdminController.java`, admin pages/screens | 8 | P0 | Strong scope, but public launch needs ops discipline |
| Notifications inbox | In-app notifications | Done | Done | Done | Done | notification endpoints | `NotificationController.java`, app/web notification UIs | 8 | P1 | Good baseline |
| Push notification token saving | Register FCM/web push token | Done | Done | Done | Done | notification token endpoints | `NotificationTokenService.java`, web push service, Flutter push service | 7 | P1 | Code-ready; live push depends on Firebase credentials |
| Email notifications | System mail and OTP mail | Done | Partial | Partial | Done | auth/support/notification mail paths | `EmailService.java`, backend configs | 7 | P1 | Needs live SMTP validation |
| Web push / Firebase web messaging | Browser push | Partial | Partial | Missing | Partial | token + push flows | `firebaseWebConfig.js`, `webPushService.js` | 6 | P2 | Works only when env is complete |
| Mobile push / Firebase app messaging | App push | Partial | Missing | Partial | Partial | token + push flows | `PushNotificationService`, `FirebaseConfig.java` | 6 | P1 | Backend credentials currently absent |
| Support / contact / legal pages | Help, tickets, static info | Done | Done | Done | Partial | support/public settings endpoints | support pages/screens/controllers | 7 | P2 | Useful but not core launch blocker |
| Monetization / subscriptions / boosts | Seller monetization stack | Done | Done | Done | Done | monetization endpoints | `MonetizationController.java`, related pages/screens | 7 | P2 | Feature-rich, but not first-order launch risk |
| Form validation | Client/server form validation | Partial | Partial | Partial | Done | auth/item/review/profile APIs | DTOs + page/screen forms | 6 | P0 | Improved, but many raw map controllers remain |
| Loading states | Visual progress indicators | Partial | Partial | Partial | N/A | all | across pages/screens | 7 | P1 | Present but inconsistent |
| Empty states | No-data UX | Done | Done | Done | N/A | all | home/wishlist/order/chat pages | 8 | P2 | Generally present |
| Error messages | User-facing errors | Partial | Partial | Partial | N/A | all | exception handler + UI error components | 6 | P0 | Often generic or logged to console only |
| Auth guards | Protected routes/screens | Done | Done | Done | N/A | all protected APIs | `App.js`, `main.dart`, auth providers | 8 | P0 | Good route-level guarding |
| Admin permissions | Role-based access | Done | Done | Done | Done | admin endpoints | `SecurityConfig.java`, admin guards | 8 | P0 | Good overall |
| Ownership checks | Users modifying only owned content | Partial | Partial | Partial | Done | items/offers/reviews/orders | controller/service checks | 7 | P0 | Present in most critical paths; some controllers still too manual |
| CORS + runtime env config | Deployment env, domains, API base URLs | Done | Partial | Done | N/A | config-only | `application-*.properties`, `runtimeConfig.js`, `api_config.dart` | 7 | P0 | Backend prod profile is solid; frontend local `.env` is risky |
| Logging + exception handling | Logs, health, readiness, API failures | Partial | Partial | Partial | N/A | all | `GlobalExceptionHandler.java`, logger usage, health controller | 6 | P0 | Health leaks internals; console noise remains |

## 5. Web App Working

### What works well

- React route structure is broad and organized.
- Major user flows exist: auth, browse, item detail, add/edit item, wishlist, chat, orders, admin.
- Production API base defaults to `https://api.mycampusmart.in/api` in `frontend/src/config/runtimeConfig.js`.
- Build is clean and small enough for an MVP: main JS bundle gzipped is about `134.75 kB`.
- Route guards exist for authenticated and admin screens in `frontend/src/App.js`.
- Web push initialization is gracefully skipped when credentials are incomplete.

### What is incomplete or risky

- Auth tokens are stored in `localStorage` in `frontend/src/api/api.js:17-38`.
- The response interceptor only uses a short `protectedRoutes` list in `src/api/api.js:135-136`; some private pages may not redirect as cleanly after auth failures.
- There is still heavy console logging in multiple user pages and chat flows.
- The repo-local `.env` contains `DANGEROUSLY_DISABLE_HOST_CHECK=true`, which must not leak into production deployment workflow.
- Profile image flow is still string-heavy and contributes to payload bloat.

### Web readiness judgment

- Functional for beta: `Yes`
- Public-launch polished: `Almost`
- Public-launch safe without fixes: `No`

## 6. Flutter App Working

### What works well

- Major parity with the web app exists.
- Secure storage is used for token storage through `flutter_secure_storage`.
- Provider-based app state is reasonable for this project size.
- Production API URL is correctly planned in `lib/config/api_config.dart`.
- Release APK builds successfully.
- Android app id is set to `com.mycampusmart.app`.
- Release cleartext traffic is disabled through manifest placeholders.

### What is incomplete or risky

- Debug runs on physical phones still require `adb reverse` or LAN API override; localhost candidates only work in specific environments.
- `lib/firebase_options.dart` is Android-centric; broader platform readiness is not complete.
- `flutter analyze` still reports `150` info-level issues, mostly async context and deprecated style usage.
- Flutter chat inbox still uses periodic polling every 30 seconds.
- The app explicitly opts out of Impeller through manifest metadata, which is not future-friendly.

### Flutter readiness judgment

- Beta-ready Android app: `Yes`
- Public-launch polished Android app: `Mostly`
- Production-safe with zero cleanup: `No`

## 7. Backend Working

### What works well

- Clear controller/service/repository separation across most modules.
- Flyway migrations exist and package/tests pass.
- Auth flow includes access token TTL and refresh token sessions.
- Rate limiting exists at endpoint and request filter levels.
- Payment flow is server-authoritative and transactional.
- Health/readiness endpoints exist.
- Dockerfile exists and packages correctly.
- Storage abstraction supports local and S3-like object storage.

### What is incomplete or risky

- Some controllers still use raw `Map<String, Object>` request bodies instead of DTOs:
  - `OfferController.java`
  - `ReviewController.java`
  - parts of auth/OTP legacy flows
- `GlobalExceptionHandler.java:74-77` maps broad `RuntimeException` to `400`, which reduces API clarity.
- Public health/readiness endpoints expose operational details.
- Some runtime logs are too verbose for public production.
- Existing persisted data still contains localhost asset URLs.

### Backend readiness judgment

- Functional for deployment: `Yes`
- Operationally hardened for public launch: `Almost`
- Fully production-safe as-is: `No`

## 8. Database Overview

### Current design

Main schema coverage is good:
- user, item, item_images, wishlist, chat, offers, orders/payments, reports, reviews, notifications, refresh sessions, registration sessions, rate-limit counters, institutions, monetization tables

### Strengths

- Flyway baseline and follow-up integrity migrations exist
- Several important unique constraints and indexes were added
- Refresh token and rate limit persistence moved into DB-backed entities
- Wishlist and chat identity integrity are materially better than earlier versions

### Weaknesses

- `students.profile_pic` is still `LONGTEXT` in `V1__initial_schema.sql` and `Student.java`.
- Existing data already contains locally scoped asset URLs.
- Legacy manual SQL files in repo root (`admin_schema.sql`, `payment_schema.sql`) create migration-drift risk for new maintainers.
- No explicit backup/restore automation is present in codebase.

### Backup readiness

- Manual backup possible: `Yes`
- Automated backup plan in repo: `No`

## 9. Payment Flow

### Current implementation quality

This is one of the strongest areas in the current codebase.

What is good:
- backend creates authoritative payment amount
- accepted offer logic is respected server-side
- verification is handled on backend
- dispute/refund/delivery paths exist
- payment state writes are transactional
- webhook endpoint exists

Main code:
- `backend/src/main/java/com/campusmart/service/PaymentService.java`
- `backend/src/main/java/com/campusmart/controller/PaymentController.java`

### Remaining payment concerns

- Live smoke with real Razorpay keys and webhook secret is still required.
- Dispute/refund flows need final manual regression with real sandbox credentials.
- Admin finance visibility should be tested with live-ish payment state transitions before public launch.

### Payment readiness score

`85/100`

## 10. Notification Flow

### Current behavior

Channels present in code:
- in-app notifications
- email notifications
- web push
- mobile push

### Current status

- In-app notifications: strong
- Email notifications: code-ready
- Web push: partial, env-dependent
- App push: partial, backend-credential dependent

### Important gap

Backend currently logs push disablement when Firebase Admin credentials are missing. That is acceptable for development, but not for a public launch that promises push notifications.

Readiness score:

`68/100`

## 11. Admin Flow

Admin coverage is broad:
- dashboard metrics
- report moderation
- logs/operational visibility
- payment and monetization visibility
- catalog/user level administration

Strengths:
- role protection is present
- web and Flutter admin surfaces both exist

Weaknesses:
- admin operational quality depends on better logging discipline
- some admin UX still relies on raw console error paths on web
- public launch should include admin SOPs, not just admin screens

## 12. Security Audit

| Issue | Severity | Location | Risk explanation | Reproduce | Recommended fix | Launch blocker |
|---|---|---|---|---|---|---|
| Web tokens stored in `localStorage` | High | `frontend/src/api/api.js:17-38` | Any successful XSS would expose access and refresh tokens, increasing account takeover blast radius | Inspect token set/get/remove paths | Move toward httpOnly cookie session model or add strict CSP + token hardening + faster expiry | No |
| Public health/readiness leaks internal details | Medium | `backend/src/main/java/com/campusmart/controller/PublicHealthController.java:77,87,94-96` | Endpoint returns database error strings, credential source hints, and inline image migration details | Hit `/api/public/ready` on a misconfigured instance | Return minimal health status only; move detailed readiness behind admin/internal auth | Yes |
| Arbitrary external image URLs allowed | High | `backend/src/main/java/com/campusmart/service/ItemImageStorageService.java` | Attackers can submit third-party URLs for tracking, broken assets, mixed-content, or abuse; ownership of media is not guaranteed | Submit item images as external URLs | Accept only backend-issued upload URLs or trusted storage/CDN prefixes | Yes |
| Profile pictures stored as `LONGTEXT` strings | High | `backend/src/main/java/com/campusmart/model/Student.java:81-82` and schema baseline | Large string payloads can bloat DB rows, API responses, memory, and bandwidth; easy abuse vector | Update profile with large base64 string | Move profile avatars to same upload pipeline used for listing images | Yes |
| Repo-local frontend env contains dangerous dev flag | Medium | `frontend/.env:1-4` | `DANGEROUSLY_DISABLE_HOST_CHECK=true` is acceptable only for local debugging and should not be part of a deployment path | Inspect repo-local `.env` | Remove from committed/dev-shared env or isolate local-only machine config | Yes |
| Broad `RuntimeException -> 400` mapping | Medium | `backend/src/main/java/com/campusmart/config/GlobalExceptionHandler.java:74-77` | Unexpected server errors may be mislabeled as client errors, hiding true incident severity and confusing clients | Trigger runtime failure in a controller/service | Map domain exceptions explicitly; return `500` for true server faults | No |
| Offer creation uses raw request map with weak validation | Medium | `backend/src/main/java/com/campusmart/controller/OfferController.java:51-78` | Business edge cases can slip through more easily than with DTO + bean validation | Submit malformed or edge-case prices | Replace with validated DTO and explicit domain checks | No |
| Review update path lacks strong validation wrapper | Medium | `backend/src/main/java/com/campusmart/controller/ReviewController.java:110-118` | Rating bounds are checked on create, but update remains too manual | Submit bad update payloads | Use DTO + `@Valid` with `@Min(1)` and `@Max(5)` | No |
| Existing stored localhost asset URLs | Medium | Data-level issue surfaced via items API runtime | Production clients will not load these images after deploy, causing broken listing media and accidental environment leakage | Inspect item API response | Run data migration to convert legacy local URLs to production asset base | Yes |
| Physical-device debug app cannot use localhost directly | Low | `campus_mart_app/lib/config/api_config.dart` | Debug builds on real phones need `adb reverse` or LAN IP; otherwise APIs fail | Run debug app on physical phone without reverse | Keep as dev note; production build already points at domain | No |

Security controls that are present and good:
- JWT access token + refresh session split
- password hashing
- endpoint rate limiting
- role-based admin protection
- Razorpay signature verification
- production profile secure transport option

## 13. Bug Audit

| Bug title | Severity | Platform | Location | Steps to reproduce | Expected | Actual | Suggested fix |
|---|---|---|---|---|---|---|---|
| Existing listing images break after deployment | High | All | Persisted item data, item APIs | Deploy current DB to public domain and open old listings | Images should render | Old rows point to `http://localhost:8081/uploads/...` | Run one-time data migration to replace legacy local URLs with public asset base |
| Oversized profile payloads in user responses | High | All | `Student.profilePic`, profile flows | Save a large avatar string and fetch profile/items | Small avatar URL payload | Response can include large string data | Move avatar storage to upload/CDN pipeline |
| Logout transaction rollback can occur | Medium | Backend/Web/Flutter | `AuthController.logout` / refresh token revoke path | Trigger logout under failing transactional revoke condition | Clean logout response | `UnexpectedRollbackException` observed in runtime log | Narrow transaction boundary and handle revoke failure explicitly |
| Offer creation lacks robust input validation | Medium | Backend/Web/Flutter | `OfferController.java` | Submit malformed or edge-case `offeredPrice` request | 4xx with clear validation | Manual parsing path is easier to break | Replace with DTO + validation annotations |
| Review update can accept weakly validated rating payload | Medium | Backend/Web/Flutter | `ReviewController.java` | Update review with bad rating value | Rejected with clear validation | Manual parsing path is less safe than create path | DTO + bean validation |
| Public readiness endpoint leaks internals | Medium | Backend | `PublicHealthController.java` | Hit `/api/public/ready` | Minimal readiness | Internal details returned | Restrict details or split public/private readiness |
| Flutter phone debug API fails without reverse/LAN setup | Low | Flutter | `api_config.dart` + local run environment | Run debug build on physical phone with only localhost backend | App should connect in dev | Requests fail to `127.0.0.1` / `localhost` | Document `adb reverse` and LAN override clearly |
| Push notifications are silently unavailable without credentials | Medium | Backend/Web/Flutter | Firebase config path | Start backend without Firebase Admin service account | Push should work if product claims it | Push is disabled gracefully but feature is unavailable | Treat live Firebase credentials as launch prerequisite |
| Web console noise in chat/profile/home | Low | Web | multiple pages in `src/pages` | Use app in dev/prod console | Minimal logs | Large debug log output | Remove debug logs or gate them behind env logger |

## 14. Performance Audit

Current performance score: `71/100`

### Biggest bottlenecks

1. Large media payloads
- item APIs still return legacy localhost image URLs
- user payloads can still include large `profilePic` string data

2. Chat inbox query pattern
- `ChatService` computes unread counts with extra per-conversation repository calls
- this creates N+1 style overhead as conversation count grows

3. Default WebSocket broker
- Spring simple broker is fine for a beta, but not ideal for larger public traffic

4. No effective response caching strategy
- no obvious cache layer for hot public data like categories, site settings, or top listings

5. Notification fan-out scalability
- backend notification fan-out exists, but long-term scale needs queues or batching discipline

### Query and schema notes

Strengths:
- item pagination exists
- key indexes exist
- integrity migrations are present

Weaknesses:
- some list/inbox patterns are still expensive
- heavy nested objects in item payloads increase response size

### Fix priority

- P0: migrate legacy media URLs, remove base64-like avatar storage
- P1: optimize chat inbox and unread count aggregation
- P1: trim item response payload shape for public browse endpoints
- P2: add selective caching for categories/site settings/home feed

## 15. Deployment Readiness

### Backend deployment

| Check | Status | Risk | Exact action needed |
|---|---|---|---|
| Dockerfile exists | Done | Low | Use `backend/Dockerfile` for Railway/Render-style deploys |
| Production profile exists | Done | Low | Keep `APP_ENV=production` explicit in deploy env |
| Port env support | Done | Low | `server.port=${PORT:8081}` already present |
| DB URL env support | Done | Low | Set `SPRING_DATASOURCE_URL`, username, password |
| Flyway production mode | Done | Medium | Run first deploy against staging snapshot before public cutover |
| Secure transport config | Done | Medium | Keep `APP_REQUIRE_SECURE_TRANSPORT=true` in production |
| CORS prod defaults | Done | Medium | Set real allowed origins explicitly for final domain(s) |
| Health endpoint | Done | Medium | Reduce public details before launch |
| Logging | Partial | Medium | Lower noisy debug logging and remove sensitive operational chatter |
| Railway/Render compatibility | Partial | Medium | Package/Docker are ready; final env and storage creds still needed |

### React deployment

| Check | Status | Risk | Exact action needed |
|---|---|---|---|
| Production build | Done | Low | `npm run build` passed |
| Vercel SPA routing | Done | Low | `vercel.json` rewrite is present |
| API base URL production path | Done | Low | `runtimeConfig.js` defaults to `api.mycampusmart.in` |
| Domain-awareness | Done | Low | `runtimeConfig.js` recognizes `mycampusmart.in` |
| Local dev env hygiene | Missing | Medium | Remove dangerous dev-only `.env` values from shared deployment path |

### Flutter release

| Check | Status | Risk | Exact action needed |
|---|---|---|---|
| Release APK build | Done | Low | `flutter build apk --release` passed |
| App name | Done | Low | `Campus Mart` set in manifest |
| Package id | Done | Low | `com.mycampusmart.app` configured |
| Release signing enforcement | Done | Medium | Provide real `android/key.properties` and production keystore in CI/release process |
| Production API URL | Done | Low | `api.mycampusmart.in` configured |
| Cleartext disabled in release | Done | Low | Manifest placeholders already separate debug/release |
| Firebase config | Partial | Medium | Final production Firebase setup still required |

### Database

| Check | Status | Risk | Exact action needed |
|---|---|---|---|
| Schema migration path | Done | Medium | Use Flyway only; avoid manual schema drift |
| Seed/demo data strategy | Partial | Medium | Decide whether launch DB will include migrated or fresh data |
| Backup plan | Missing | High | Create scheduled backup/restore process before launch |
| Legacy asset URL cleanup | Missing | High | Migrate old local URLs before pointing clients at production |

### Domain and SSL

| Check | Status | Risk | Exact action needed |
|---|---|---|---|
| Frontend domain planned | Done | Low | Point `mycampusmart.in` to web hosting |
| API domain planned | Done | Low | Point `api.mycampusmart.in` to backend hosting |
| DNS live config | Missing | Medium | Create final A/CNAME records |
| SSL | Missing | High | Enable HTTPS for both root and API before public traffic |

## 16. Product / Startup Readiness

### Is the product launchable?

- Internal demo launch: `Yes`
- Closed beta launch: `Yes`
- Public launch today: `No`

### Strongest features

- Real marketplace depth, not just listing CRUD
- Web and Flutter parity is strong
- Payments, offers, chat, reviews, and admin are all present
- Production URLs and release Android packaging are already in place

### Weakest areas

- media and avatar storage hygiene
- push notification live readiness
- operational/security hardening around public diagnostics and frontend token strategy
- some manual controller validation patterns

### Features unnecessary right now

- Some monetization complexity is not a public-launch prerequisite
- Overly broad support/static content surface can wait on polish

### Features missing for trust

- guaranteed media integrity for all existing listings
- production-safe avatar/media handling
- cleaner error UX
- live push/email/OTP smoke with final credentials

### Features missing for retention

- more reliable notifications
- faster chat inbox updates without polling fallback
- lighter payloads on mobile networks

### Features missing for monetization

- final live payment credential rollout and finance smoke tests

### What should be done before launch

- fix all P0 items in section 18
- run real-credential staging smoke pass
- migrate legacy local media URLs

### What should be done after launch

- improve analytics, observability, and support operations
- reduce frontend and Flutter debug/log debt
- optimize inbox/query and asset delivery performance

## 17. Missing Features

Not all of these are launch blockers, but they are still missing or incomplete:
- automated backup/restore workflow
- private/internal readiness endpoint separate from public health
- object-storage-based avatar pipeline
- stricter DTO coverage for remaining raw-map controllers
- queue-backed notification fan-out
- broker-relay-backed chat for higher concurrency
- stronger CSP/XSS hardening strategy for web auth storage
- complete live notification credential validation

## 18. P0 / P1 / P2 / P3 Priority Roadmap

### P0: Must fix before public launch

1. Migrate all existing listing image URLs away from `localhost`.
2. Move `profilePic` off `LONGTEXT` string storage into the upload/CDN pipeline.
3. Restrict listing images to trusted upload/CDN URLs only.
4. Reduce public health/readiness responses to minimal safe status.
5. Remove `DANGEROUSLY_DISABLE_HOST_CHECK=true` from shared frontend deployment path.
6. Fix logout rollback path in refresh token revocation flow.
7. Replace manual offer/review validation with DTO + bean validation.
8. Run final staging smoke with real Razorpay, Firebase, Twilio, mail, and domain config.

### P1: Fix within first 2 weeks after beta

1. Remove excessive console/debug logging across web pages and backend services.
2. Optimize chat inbox unread count and polling behavior.
3. Improve API error taxonomy beyond broad `RuntimeException -> 400`.
4. Reduce heavy nested payloads in public item APIs.
5. Clean Flutter analyzer backlog.

### P2: Growth features

1. Add caching for categories, site settings, and popular feed data.
2. Add richer notification preference management.
3. Improve institution onboarding and multi-college normalization.

### P3: Later / optional

1. Expand monetization and seller subscription polish.
2. Add more analytics and cohort tooling.
3. Broaden cross-platform Flutter support beyond Android focus.

## 19. Testing Plan

### Manual test cases

| ID | Feature | Steps | Expected result | Priority | Platform |
|---|---|---|---|---|---|
| API-01 | Health | `GET /api/public/health` | 200 minimal health JSON | P1 | Backend |
| API-02 | Registration | Create new registration session and verify both OTPs | User account created, tokens returned | P0 | Backend/Web/Flutter |
| API-03 | Login | Login with valid credentials | Access + refresh token returned | P0 | Backend/Web/Flutter |
| API-04 | Token refresh | Wait/force expired access token, trigger refresh | Request recovers using refresh token | P0 | Web/Flutter |
| API-05 | Logout | Logout current device | Token/session revoked cleanly | P0 | Backend/Web/Flutter |
| ITEM-01 | Create item | Upload images and submit new listing | Listing appears in my items and browse | P0 | Web/Flutter |
| ITEM-02 | Edit item | Update title/price/images | Updated values persist | P0 | Web/Flutter |
| ITEM-03 | Delete item | Delete own item | Listing removed from personal inventory and hidden from browse | P1 | Web/Flutter |
| ITEM-04 | Legacy media | Open older migrated listings | Images load from public storage, not localhost | P0 | All |
| SEARCH-01 | Browse/search | Apply keyword + filters + sort | Correct filtered paginated results | P0 | Web/Flutter |
| WISH-01 | Wishlist | Add/remove wishlist item | State updates immediately and persists | P1 | Web/Flutter |
| CHAT-01 | Chat send/receive | Message another user from item detail | Message persists and inbox updates | P0 | Web/Flutter |
| OFFER-01 | Create offer | Submit offer on available item | Offer stored and visible to seller | P0 | Web/Flutter |
| OFFER-02 | Accept offer | Seller accepts offer, buyer opens payment | Payable amount reflects accepted offer | P0 | Web/Flutter |
| PAY-01 | Create order | Start Razorpay checkout | Backend creates correct order | P0 | Web/Flutter/Backend |
| PAY-02 | Verify payment | Complete sandbox payment | Payment marked verified | P0 | All |
| PAY-03 | Delivery confirm | Buyer confirms delivery | Order state advances correctly | P0 | All |
| PAY-04 | Dispute | Raise dispute on paid order | Dispute state and timeline update | P0 | All |
| REV-01 | Review create | Submit review after order | Review appears in item/seller context | P1 | Web/Flutter |
| REPORT-01 | Report item/user | Submit report | Report appears in admin flow | P0 | Web/Flutter/Admin |
| ADMIN-01 | Admin auth | Login as admin and open dashboard | Admin-only pages accessible | P0 | Web/Flutter |
| ADMIN-02 | Moderation | Review a report and act | Action persists | P0 | Admin |
| NOTIF-01 | Push token save | Grant permission and log in | Token saved to backend | P1 | Web/Flutter |
| NOTIF-02 | Push delivery | Trigger message/offer event with live Firebase creds | Push received on target device | P0 | Web/Flutter |
| SEC-01 | Unauthorized access | Call protected API without token | 401/403 returned | P0 | Backend |
| SEC-02 | Ownership | Attempt to modify another user’s item | Request denied | P0 | Backend |
| SEC-03 | Media abuse | Try arbitrary remote image URL | Request rejected after fix | P0 | Backend/Web/Flutter |
| RESP-01 | Mobile responsiveness | Open web app on phone browser | Layout remains usable | P1 | Web |

### Unit tests needed

- offer validation DTO tests
- review DTO validation tests
- image URL whitelist/ownership validation tests
- profile image upload migration tests

### Integration tests needed

- registration session full flow
- refresh token revoke/logout paths
- payment create/verify/dispute/refund paths
- notification token register/clear flows

### End-to-end tests needed

- happy-path buyer journey from browse to payment to review
- seller journey from listing to offer to payout/dispute outcome
- admin moderation path

### Postman collection recommendations

Create collections for:
- auth
- items/search
- wishlist
- chat
- offers
- payments
- admin
- notifications
- support

## 20. Final Scorecard

| Area | Score /100 |
|---|---:|
| Backend code quality | 82 |
| Web frontend quality | 78 |
| Flutter app quality | 77 |
| Database design | 80 |
| Security | 74 |
| Performance | 71 |
| Payment readiness | 85 |
| Notification readiness | 68 |
| Deployment readiness | 82 |
| UI/UX | 80 |
| Product readiness | 84 |
| Startup MVP readiness | 86 |
| Overall launch readiness | 81 |

Summary:
- Beta launch readiness percentage: `90%`
- Public launch readiness percentage: `78%`
- Risk level: `Medium`
- Estimated time to beta launch: `2-4 days`
- Estimated time to public launch: `1-2 weeks`

## 21. Launch Recommendation

Recommendation: `Beta launch after fixes`

You can run a controlled beta now if you accept:
- live credentials still need to be added
- push notifications are not fully production-ready until Firebase Admin is configured
- legacy media URLs and avatar storage must still be cleaned before public launch

You should not do a full public launch today because the current asset and payload risks would cause broken listings, unnecessary bandwidth usage, and avoidable operational exposure.

## 22. Next 7-Day Action Plan

### Day 1

- Remove public readiness leakage
- remove dangerous shared frontend dev flag
- patch offer/review DTO validation

### Day 2

- implement avatar upload pipeline
- migrate `profilePic` off `LONGTEXT` payload use

### Day 3

- migrate all legacy `localhost` listing images to public asset URLs
- block arbitrary external item image URLs

### Day 4

- run full staging deploy with production-like env
- wire Firebase Admin, SMTP, Twilio, Razorpay sandbox/live-ready config

### Day 5

- run payment, dispute, review, report, admin, and notification smoke pass
- verify Android release install and real-device notification flow

### Day 6

- reduce web/backend debug logging
- fix logout rollback issue
- optimize chat inbox hot paths

### Day 7

- final DNS + SSL setup
- run pre-launch checklist
- public launch go/no-go review

---

Short final verdict: `Beta launch after fixes`

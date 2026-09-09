# CampusMart Beta Launch - Practical Action Plan
**Date**: May 4, 2026  
**Goal**: Launch to closed beta within 7-10 days  

---

## 📋 Week 1: Infrastructure & Configuration Setup

### Day 1-2: Cloud Infrastructure

#### **AWS S3 Setup** (30 min)
```bash
# Create S3 bucket for media storage
aws s3 mb s3://campusmart-prod-media-2026 --region ap-south-1

# Create IAM user for app access
# Give S3FullAccess to bucket only (not all S3)

# Get credentials (Access Key ID + Secret)
```

**Env Variables to Document:**
```
APP_STORAGE_S3_BUCKET=campusmart-prod-media-2026
APP_STORAGE_S3_REGION=ap-south-1
APP_STORAGE_S3_ENDPOINT=s3.ap-south-1.amazonaws.com
APP_STORAGE_S3_ACCESS_KEY=AKIA...
APP_STORAGE_S3_SECRET_KEY=...
APP_STORAGE_S3_PUBLIC_BASE_URL=https://d123456.cloudfront.net
```

#### **Firebase Configuration** (45 min)

1. **Create Firebase Project** for production
2. **Android Configuration:**
   - Register app with package ID: `in.mycampusmart.app` (final)
   - Download `google-services.json`
   - Place in `campus_mart_app/android/app/`

3. **Web Configuration:**
   - Register web app
   - Copy Firebase config
   - Update `frontend/public/firebase-messaging-sw.js`

4. **Generate Server Credentials:**
   - Create service account key (JSON)
   - Place in `backend/firebase-key.json`

**Env Variables:**
```
FIREBASE_PROJECT_ID=campusmart-prod
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
```

#### **Database Setup** (30 min)

```bash
# Option 1: AWS RDS
# - Create MySQL 8.0 instance
# - Enable automated backups
# - Allow inbound from backend host on port 3306
# - Get endpoint (e.g., campus-mart-db.c123.ap-south-1.rds.amazonaws.com)

# Option 2: Self-managed cloud MySQL
# - Set up with proper backups
# - Configure SSL certificates
```

**Env Variables:**
```
SPRING_DATASOURCE_URL=jdbc:mysql://campus-mart-db.c123.ap-south-1.rds.amazonaws.com:3306/campus_mart_prod?useSSL=true&serverTimezone=UTC
DB_USERNAME=campusmart_admin
DB_PASSWORD=strong_password_here
FLYWAY_ENABLED=true
```

### Day 2-3: External Services

#### **Email Service Setup** (30 min)

**Using Gmail:**
```
1. Create Google App Password (not regular password)
   - Go to Google Account > Security > App Passwords
   - Select Mail > Windows Computer
   - Copy app-specific password

2. Set Env Variables:
   MAIL_USERNAME=noreply@mycampusmart.in
   MAIL_PASSWORD=your-app-specific-password
   NOTIFICATIONS_FROM_EMAIL=noreply@mycampusmart.in
```

**Alternative: SendGrid**
```
1. Create SendGrid account
2. Create API key
3. Set Env Variables:
   MAIL_USERNAME=apikey
   MAIL_PASSWORD=SG.xxxxx
```

#### **SMS Service Setup (Twilio)** (30 min)

```
1. Create Twilio account
2. Get Account SID and Auth Token
3. Verify and buy phone number (e.g., +1234567890 or Indian number)
4. Set Env Variables:

TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=+91xxxxxxxxxx
```

**Test OTP Flow:**
```bash
# Register test account
POST /api/auth/register
{
  "email": "test@example.com",
  "phoneNumber": "+91xxxxxxxxxx",
  "password": "Test@123"
}

# Should receive email OTP first
# Then phone OTP
# Verify both to create account
```

#### **Payment Service Setup (Razorpay)** (1 hour)

```
1. Create Razorpay account (Business registration required)
2. Go to Settings > API Keys
3. Copy:
   - Key ID (public)
   - Key Secret (confidential)

4. Set Env Variables:
   RAZORPAY_KEY_ID=rzp_live_...
   RAZORPAY_KEY_SECRET=...

5. Configure Webhook:
   - Endpoint: https://api.mycampusmart.in/api/webhooks/razorpay
   - Events: payment.authorized, payment.failed, order.paid
```

**Test Payment Flow:**
```bash
# Test order creation
POST /api/payments/create-order
{
  "itemId": 1,
  "amount": 999,
  "offerId": null
}

# Frontend opens Razorpay Checkout
# Complete payment in sandbox mode first
```

---

## 📦 Week 1-2: Build & Deployment

### Day 4-5: Android Release Build

#### **Step 1: Generate Release Keystore**
```bash
cd campus_mart_app/android/app

# Generate keystore (one-time)
keytool -genkey -v -keystore campus_mart.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias campus_mart_key \
  -storepass your_store_password \
  -keypass your_key_password

# Create key.properties file
cat > key.properties << EOF
storeFile=../app/campus_mart.keystore
storePassword=your_store_password
keyAlias=campus_mart_key
keyPassword=your_key_password
EOF
```

#### **Step 2: Update build.gradle.kts**
```kotlin
val androidApplicationId = "in.mycampusmart.app"  // Set final package ID
```

#### **Step 3: Build Release APK**
```bash
# From project root
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.mycampusmart.in \
  --dart-define=APP_ENV=production

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### **Step 4: Distribute via Firebase App Distribution**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Upload to beta testers
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app=1:123456789:android:abc123... \
  --release-notes="Beta v1.0" \
  --testers="beta@example.com,test@example.com"
```

### Day 5-6: Backend Deployment

#### **Option 1: Render.com** (Simplest)

```bash
# 1. Connect GitHub repo
# 2. Create new Web Service
# 3. Configure:
#    - Build Command: mvn clean package -DskipTests
#    - Start Command: java -jar target/campus-mart-0.0.1-SNAPSHOT.jar
#    - Environment: Add all env variables above

# 4. Add custom domain: api.mycampusmart.in
# 5. Enable SSL
# 6. Deploy
```

#### **Option 2: Railway** (Also Simple)

```bash
# 1. Connect GitHub
# 2. New Project > Create Service
# 3. Select Java
# 4. Add environment variables
# 5. Add MySQL add-on
# 6. Deploy
```

#### **Verify Backend**
```bash
# Test health endpoint
curl https://api.mycampusmart.in/api/public/health

# Should return:
{
  "status": "UP",
  "environment": "production"
}

# Test OTP registration
curl -X POST https://api.mycampusmart.in/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "beta@test.in",
    "phoneNumber": "+91xxxxxxxxxx",
    "password": "Test@123",
    "studentName": "Test Student",
    "institutionId": 1
  }'
```

### Day 6-7: Web Frontend Deployment

#### **Option 1: Vercel** (Recommended for Next.js, but works for React)

```bash
# 1. Import project from GitHub
# 2. Configure:
#    - Build Command: npm run build
#    - Output Directory: build
# 3. Environment Variables:
#    REACT_APP_API_BASE_URL=https://api.mycampusmart.in
#    REACT_APP_WS_BASE_URL=wss://api.mycampusmart.in
#    REACT_APP_FIREBASE_CONFIG={...}

# 4. Add custom domain: mycampusmart.in
# 5. Deploy
```

#### **Option 2: Netlify**

```bash
# 1. Connect GitHub
# 2. Build & Deploy
# 3. Add environment variables
# 4. Configure redirects for SPA:
   [[redirects]]
   from = "/*"
   to = "/index.html"
   status = 200
# 5. Add domain
```

#### **Test Web Frontend**
```bash
# Visit https://mycampusmart.in
# Test registration flow
# Verify API connectivity in Network tab (no CORS errors)
# Test push notifications
```

---

## 🧪 Week 2: Testing & Verification

### Day 1: Manual Testing Checklist

#### **Authentication Flow**
- [ ] Register new account with email + phone OTP
- [ ] Verify email and phone OTP separately
- [ ] Login with registered credentials
- [ ] Refresh token on session expiry
- [ ] Logout clears all tokens

#### **Item Listing**
- [ ] Upload item with multiple images
- [ ] Images persist after upload
- [ ] Edit item successfully
- [ ] Delete item removes from marketplace
- [ ] Browse items on home page
- [ ] Search by keyword works
- [ ] Filters work (price, category, location)

#### **Payment Flow** (Use Razorpay Sandbox)
- [ ] Create offer on item
- [ ] Seller accepts offer
- [ ] Buyer initiates payment
- [ ] Razorpay checkout appears
- [ ] Complete payment with test card
- [ ] Order status updates to PAID
- [ ] Seller sees order in My Orders

#### **Chat**
- [ ] Start chat from item detail
- [ ] Send real-time message
- [ ] Message appears on both sides
- [ ] Unread count works
- [ ] Chat history loads correctly

#### **Admin**
- [ ] Login as admin
- [ ] View dashboard metrics
- [ ] Moderate reports
- [ ] Update site settings
- [ ] View payment orders

### Day 2-3: Load Testing (Optional for Beta)

```bash
# Install Apache Bench or similar
ab -n 100 -c 10 https://api.mycampusmart.in/api/public/health

# Monitor response times and server load
```

### Day 3: Security Verification

```bash
# Check CORS headers
curl -i https://api.mycampusmart.in/api/items

# Should see:
# Access-Control-Allow-Origin: https://mycampusmart.in

# Verify SSL
curl -I https://mycampusmart.in
curl -I https://api.mycampusmart.in

# Check for security headers
# Verify no dev endpoints are exposed
```

---

## 📱 Production Environment Variables Template

Create `.env.production` (keep secure!):

```bash
# ===== ENVIRONMENT =====
APP_ENV=production
APP_EXPOSE_DEV_OTP=false
APP_DETAILED_ERRORS=false

# ===== DATABASE =====
SPRING_DATASOURCE_URL=jdbc:mysql://your-db-host:3306/campus_mart_prod?useSSL=true&serverTimezone=UTC
DB_USERNAME=campusmart_admin
DB_PASSWORD=<STRONG_PASSWORD>

# ===== STORAGE =====
APP_STORAGE_MODE=s3
APP_STORAGE_S3_BUCKET=campusmart-prod-media-2026
APP_STORAGE_S3_REGION=ap-south-1
APP_STORAGE_S3_ACCESS_KEY=<AWS_ACCESS_KEY>
APP_STORAGE_S3_SECRET_KEY=<AWS_SECRET_KEY>
APP_STORAGE_S3_PUBLIC_BASE_URL=https://d123.cloudfront.net
APP_UPLOADS_PUBLIC_BASE_URL=https://d123.cloudfront.net

# ===== EMAIL =====
MAIL_USERNAME=noreply@mycampusmart.in
MAIL_PASSWORD=<APP_SPECIFIC_PASSWORD>
NOTIFICATIONS_FROM_EMAIL=noreply@mycampusmart.in

# ===== SMS =====
TWILIO_ACCOUNT_SID=<ACCOUNT_SID>
TWILIO_AUTH_TOKEN=<AUTH_TOKEN>
TWILIO_PHONE_NUMBER=+91xxxxxxxxxx

# ===== FIREBASE =====
FIREBASE_PROJECT_ID=campusmart-prod
FIREBASE_PRIVATE_KEY=<JSON_KEY_CONTENT>
FIREBASE_CLIENT_EMAIL=<SERVICE_ACCOUNT_EMAIL>

# ===== PAYMENT =====
RAZORPAY_KEY_ID=rzp_live_xxxxx
RAZORPAY_KEY_SECRET=<SECRET_KEY>

# ===== CORS & DOMAINS =====
APP_FRONTEND_BASE_URL=https://mycampusmart.in
APP_CORS_ALLOWED_ORIGINS=https://mycampusmart.in,https://www.mycampusmart.in
APP_WEBSOCKET_ALLOWED_ORIGINS=https://mycampusmart.in,https://www.mycampusmart.in
```

---

## 🚨 Day-of-Launch Checklist

- [ ] All environment variables configured and tested
- [ ] Database backups enabled and tested
- [ ] S3 bucket accessible and tested
- [ ] Email service tested (send test OTP)
- [ ] SMS service tested (send test SMS)
- [ ] Payment service in production mode (not sandbox)
- [ ] Firebase push credentials active
- [ ] SSL certificates valid on all domains
- [ ] API health endpoint returns `"status": "UP"`
- [ ] Frontend loads without CORS errors
- [ ] Flutter APK signed and distributed
- [ ] Beta testers added to Firebase App Distribution
- [ ] Support contact emails configured
- [ ] Monitoring/alerting set up (optional but recommended)

---

## 📞 Quick Debugging Guide

| Issue | Solution |
|-------|----------|
| 401 Unauthorized on API calls | Check JWT token expiry, try refresh endpoint |
| CORS errors in browser | Verify APP_CORS_ALLOWED_ORIGINS matches your domain |
| Images not uploading | Check S3 bucket permissions and access keys |
| OTP not received | Verify Twilio account balance and phone number |
| Payment fails | Check Razorpay key credentials, use test card first |
| Chat not connecting | Verify WebSocket URL in frontend config |

---

**Timeline**: 7-10 days total  
**Team Size**: 1-2 people per platform minimum  
**Go-Live**: After Day 7 checks pass

Good luck! 🚀

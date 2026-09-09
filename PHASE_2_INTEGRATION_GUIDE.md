# PHASE 2 CRITICAL FIXES - IMPLEMENTATION GUIDE

**Updated:** April 27, 2026 | **Status:** 60% Complete

---

## OVERVIEW

Phase 2 implements 3 critical security & performance fixes:

1. ✅ **Flyway Migrations** - Database schema version control (COMPLETE)
2. ✅ **Rate Limiting** - Brute force & DoS protection (COMPLETE - needs integration)
3. ⏳ **Secrets Management** - Remove .env from git (PENDING)

---

## COMPLETED: FLYWAY DATABASE MIGRATIONS

### Files Created:
- ✅ `src/main/resources/db/migration/V1__initial_schema.sql` (450 lines)
- ✅ `src/main/resources/db/migration/V2__add_indexes.sql` (40 lines)
- ✅ Updated `application.properties` with Flyway config

### What it does:
- Automatic schema creation on first application startup
- Version-controlled database changes
- Prevents `ddl-auto=update` corruption issues
- Includes performance indexes

### Deployment impact:
```
First run: V1 creates schema + V2 adds indexes automatically
Next deployments: Only new scripts run, old ones skipped
```

---

## COMPLETED: RATE LIMITING SYSTEM

### Files Created:
- ✅ `src/main/java/com/campusmart/util/RateLimiter.java` (110 lines)
- ✅ `src/main/java/com/campusmart/util/ServletUtils.java` (80 lines)
- ✅ Added `bucket4j-core` to `pom.xml`

### Rate Limits Configured:

| Endpoint | Limit | Window | Purpose |
|----------|-------|--------|---------|
| Login | 5/person | per minute | Stop brute force password guessing |
| OTP Gen | 3/email | per 30 min | Prevent spam registration |
| OTP Verify | 5/email | per 15 min | Stop brute force OTP guessing |
| Password Reset | 3/email | per hour | Limit account recovery spam |
| Create Order | 10/user | per minute | Prevent payment spam |
| Create Item | 30/user | per hour | Prevent listing spam |
| Send Message | 50/user | per minute | Prevent chat spam |
| Create Offer | 20/user | per hour | Prevent offer spam |

---

## IN PROGRESS: CONTROLLER INTEGRATION

### Step 1: AuthController

**File:** `backend/src/main/java/com/campusmart/controller/AuthController.java`

**Add imports:**
```java
import com.campusmart.util.RateLimiter;
import com.campusmart.util.ServletUtils;
import jakarta.servlet.http.HttpServletRequest;
```

**Add field:**
```java
@Autowired private RateLimiter rateLimiter;
```

**Modify `@PostMapping("/login")` method - ADD RATE LIMIT CHECK:**

Find this code (~line 250):
```java
@PostMapping("/login")
public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
    try {
        String email    = body.getOrDefault("email",    "").trim().toLowerCase();
        String password = body.getOrDefault("password", "").trim();

        if (email.isEmpty() || password.isEmpty())
            return error("Email and password are required");
```

Replace with:
```java
@PostMapping("/login")
public ResponseEntity<?> login(@RequestBody Map<String, String> body, HttpServletRequest request) {
    try {
        String email    = body.getOrDefault("email",    "").trim().toLowerCase();
        String password = body.getOrDefault("password", "").trim();

        if (email.isEmpty() || password.isEmpty())
            return error("Email and password are required");
        
        // RATE LIMITING: 5 login attempts per minute per IP
        String clientIp = ServletUtils.getClientIp(request);
        if (!rateLimiter.allowLogin(clientIp)) {
            return ResponseEntity.status(429).body(Map.of(
                "error", "Too many login attempts. Please try again after 1 minute.",
                "remaining_attempts", 0
            ));
        }
```

**Modify `@PostMapping("/register")` method - ADD RATE LIMIT CHECK:**

Find this code (~line 50):
```java
@PostMapping("/register")
public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
    try {
        String name  = body.getOrDefault("name",  "").trim();
        String email = body.getOrDefault("email", "").trim().toLowerCase();
        String password = body.getOrDefault("password", "").trim();
        String phone = body.getOrDefault("phone", "").trim();
```

Replace with:
```java
@PostMapping("/register")
public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
    try {
        String name  = body.getOrDefault("name",  "").trim();
        String email = body.getOrDefault("email", "").trim().toLowerCase();
        String password = body.getOrDefault("password", "").trim();
        String phone = body.getOrDefault("phone", "").trim();
        
        // RATE LIMITING: 3 registration attempts per 30 minutes per email
        if (!rateLimiter.allowOtpGeneration(email)) {
            return error("Too many registration attempts. Please try again in 30 minutes.");
        }
```

**Modify `@PostMapping("/verify-email")` method - ADD RATE LIMIT CHECK:**

Find this code (~line 110):
```java
@PostMapping("/verify-email")
public ResponseEntity<?> verifyEmail(@RequestBody Map<String, Object> body) {
    try {
        Long   sessionId = Long.valueOf(body.get("sessionId").toString());
        String otp       = body.get("otp").toString().trim();
```

Replace with:
```java
@PostMapping("/verify-email")
public ResponseEntity<?> verifyEmail(@RequestBody Map<String, Object> body) {
    try {
        Long   sessionId = Long.valueOf(body.get("sessionId").toString());
        String otp       = body.get("otp").toString().trim();
        
        // Extract email from session for rate limiting
        RegistrationSession tempSession = regSessionRepo.findById(sessionId)
                .orElseThrow(() -> new RuntimeException("Session not found"));
        String email = tempSession.getEmail();
        
        // RATE LIMITING: 5 OTP verification attempts per 15 minutes per email
        if (!rateLimiter.allowOtpVerification(email)) {
            return error("Too many OTP verification attempts. Please try again in 15 minutes.");
        }
```

**Modify `@PostMapping("/forgot-password/request")` method - ADD RATE LIMIT CHECK:**

Find this code (~line 360):
```java
@PostMapping("/forgot-password/request")
public ResponseEntity<?> requestForgotPassword(@RequestBody Map<String, String> body) {
    try {
        String email = body.getOrDefault("email", "").trim().toLowerCase();
        if (email.isEmpty()) {
            return error("Email is required");
        }
```

Replace with:
```java
@PostMapping("/forgot-password/request")
public ResponseEntity<?> requestForgotPassword(@RequestBody Map<String, String> body) {
    try {
        String email = body.getOrDefault("email", "").trim().toLowerCase();
        if (email.isEmpty()) {
            return error("Email is required");
        }
        
        // RATE LIMITING: 3 password reset requests per hour per email
        if (!rateLimiter.allowPasswordReset(email)) {
            return error("Too many password reset attempts. Please try again in 1 hour.");
        }
```

---

### Step 2: PaymentController

**File:** `backend/src/main/java/com/campusmart/controller/PaymentController.java`

**Add imports & field (same pattern as AuthController)**

**Find `@PostMapping` for order creation (~line 30-50) and ADD:**
```java
// RATE LIMITING: 10 order creation attempts per minute per user
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateOrder(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of(
        "error", "Too many order attempts. Please try again after 1 minute."
    ));
}
```

---

### Step 3: ItemController

**File:** `backend/src/main/java/com/campusmart/controller/ItemController.java`

**Add imports & field (same pattern)**

**Find `@PostMapping` for item creation and ADD:**
```java
// RATE LIMITING: 30 items per hour per user
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateItem(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of(
        "error", "Daily item limit reached. Maximum 30 items per hour."
    ));
}
```

---

### Step 4: ChatController

**File:** `backend/src/main/java/com/campusmart/controller/ChatController.java`

**Add imports & field (same pattern)**

**Find `@MessageMapping("/chat.send")` method and ADD after JWT validation:**
```java
// RATE LIMITING: 50 messages per minute per user
if (!rateLimiter.allowSendMessage(senderId.toString())) {
    throw new RuntimeException("Message rate limit exceeded. Maximum 50 messages per minute.");
}
```

---

### Step 5: OfferController

**File:** `backend/src/main/java/com/campusmart/controller/OfferController.java`

**Add imports & field (same pattern)**

**Find `@PostMapping` for offer creation and ADD:**
```java
// RATE LIMITING: 20 offers per hour per user
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateOffer(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of(
        "error", "Offer limit reached. Maximum 20 offers per hour."
    ));
}
```

---

## PENDING: SECRETS REMOVAL FROM GIT

### Step 1: Create `.env.example`

**File:** `backend/.env.example`

```properties
# ========================================
# ENVIRONMENT TEMPLATE - DO NOT COMMIT ACTUAL VALUES
# ========================================

# Database Configuration
DB_USERNAME=root
DB_PASSWORD=your_secure_password_here
DB_HOST=localhost
DB_PORT=3306

# JWT Secret
JWT_SECRET=your_random_jwt_secret_here_min_32_chars

# Twilio SMS (Get from: https://www.twilio.com/console)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_PHONE_NUMBER=+1234567890

# Gmail SMTP (Generate App Password: https://myaccount.google.com/apppasswords)
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your_16char_app_password

# Firebase Service Account (Download from Firebase Console)
FIREBASE_SERVICE_ACCOUNT_PATH=src/main/resources/firebase-service-account.json

# Frontend URL
APP_FRONTEND_BASE_URL=http://localhost:3000
APP_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
APP_WEBSOCKET_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# Razorpay (Get test keys from: https://dashboard.razorpay.com)
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_secret_key_here

# Notifications
NOTIFICATIONS_EMAIL_ENABLED=true
NOTIFICATIONS_PUSH_ENABLED=true
NOTIFICATIONS_FROM_EMAIL=noreply@campusmart.com
```

### Step 2: Update `.gitignore`

**File:** `backend/.gitignore`

Add this line (if not already present):
```
.env
```

### Step 3: Remove from Git History

```bash
cd backend

# Remove .env from git tracking
git rm --cached .env

# Add to ignore list
git add .gitignore
git add .env.example

# Commit changes
git commit -m "security: remove sensitive .env from version control"

# Push to repository
git push origin main
```

### Step 4: Setup on Deployment Platforms

**For Railway:**
1. Go to your service in Railway
2. Click "Variables"
3. Add each variable from `.env`
4. Save and redeploy

**For Render:**
1. Go to your service settings
2. Click "Environment"
3. Add each variable
4. Save and redeploy

**For AWS:**
1. Use AWS Secrets Manager or Parameter Store
2. Store as secure parameters
3. Reference in application startup

---

## IMPLEMENTATION CHECKLIST

### Flyway Setup
- [x] Add Flyway dependencies to pom.xml
- [x] Create migration directory structure
- [x] Create V1__initial_schema.sql
- [x] Create V2__add_indexes.sql
- [x] Update application.properties
- [x] Verify compilation

### Rate Limiting
- [x] Create RateLimiter.java
- [x] Create ServletUtils.java
- [x] Add bucket4j dependency
- [x] Verify compilation
- [ ] Add @Autowired to AuthController
- [ ] Modify /login endpoint
- [ ] Modify /register endpoint
- [ ] Modify /verify-email endpoint
- [ ] Modify /forgot-password/request endpoint
- [ ] Add to PaymentController
- [ ] Add to ItemController
- [ ] Add to ChatController
- [ ] Add to OfferController

### Secrets Management
- [ ] Create .env.example
- [ ] Update .gitignore
- [ ] Git rm --cached .env
- [ ] Git commit & push
- [ ] Configure on Railway
- [ ] Configure on Render
- [ ] Test with environment variables

### Testing & Verification
- [ ] mvn clean compile (should succeed)
- [ ] mvn test (run new integration tests)
- [ ] Manual testing: Rate limit triggers at correct thresholds
- [ ] Database migration: First run creates schema
- [ ] Deployment: Environment variables load correctly

---

## ESTIMATED TIME

- Controller integration: 2-3 hours
- Secrets cleanup: 1-2 hours
- Testing: 2-3 hours
- **Total Phase 2 remaining: 6-8 hours**

---

## TESTING COMMANDS

Once integration is complete:

```bash
# Compile
cd backend
mvn clean compile

# Run tests
mvn test

# Start application
mvn spring-boot:run

# Test rate limiting (in another terminal)
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"wrong"}' \
  # Repeat 6 times - 6th request should get 429 error
```

---

**Next Session:** Start with AuthController integration

# PHASE 2 - CRITICAL ISSUES FIX

**Target:** Fix 5 critical blocking issues  
**Priority Level:** URGENT - Required before production launch  
**Target Score:** 65-70% (from 58%)  
**Timeline:** 1-2 weeks

---

## 🔴 CRITICAL ISSUE #1: WebSocket Security

**Severity:** CRITICAL  
**Impact:** Message spoofing, chat compromise  
**Current Status:** UNSAFE - CORS open, senderId not validated  
**Effort:** 2-3 hours  
**Priority:** 1st (Fix immediately)

### Problem

```java
// WebSocketConfig.java
.setAllowedOriginPatterns("*")  // ❌ Accepts ANY origin

// ChatController.java
@MessageMapping("/chat.send")
public void handleMessage(@Payload Map<String, Object> payload) {
    Long senderId = Long.valueOf(payload.get("senderId").toString());
    // ❌ Client can claim to be ANY user
    chatService.sendMessage(senderId, receiverId, itemId, content);
}
```

**Attack Scenario:**
```
User A could spoof User B's chat messages by:
1. Open browser dev console
2. Connect to WebSocket: ws://api/ws
3. Send message with senderId=B (any user ID)
4. Message appears as if from B
```

### Solution

**Step 1: Restrict WebSocket CORS**

**File:** `backend/src/main/java/com/campusmart/config/WebSocketConfig.java`

```java
package com.campusmart.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.*;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Value("${app.websocket.allowed-origins:http://localhost:3000,http://localhost:3001}")
    private String allowedOrigins;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        String[] origins = allowedOrigins.split(",");
        for (int i = 0; i < origins.length; i++) {
            origins[i] = origins[i].trim();
        }
        
        registry
            .addEndpoint("/ws")
            .setAllowedOrigins(origins)  // ✅ Restrict to configured origins only
            .withSockJS();
    }
}
```

**Step 2: Bind WebSocket to JWT Identity**

**File:** `backend/src/main/java/com/campusmart/controller/ChatController.java`

```java
@MessageMapping("/chat.send")
public void handleMessage(@Payload Map<String, Object> payload, 
                         Principal principal) {  // ✅ Principal from JWT
    try {
        // Get authenticated user from JWT
        Long senderId = SecurityUtils.getCurrentUserId();  // ✅ NOT from client
        
        Long receiverId = Long.valueOf(payload.get("receiverId").toString());
        Long itemId = payload.get("itemId") != null
            ? Long.valueOf(payload.get("itemId").toString())
            : null;
        String content = payload.get("content").toString();

        // Validate receiver exists and is not sender
        if (senderId.equals(receiverId)) {
            throw new RuntimeException("Cannot message yourself");
        }

        chatService.sendMessage(senderId, receiverId, itemId, content);
    } catch (Exception e) {
        System.err.println("WS Error in /chat.send: " + e.getMessage());
    }
}

@MessageMapping("/chat.typing")
public void handleTyping(@Payload Map<String, Object> payload,
                        Principal principal) {  // ✅ Principal from JWT
    try {
        Long senderId = SecurityUtils.getCurrentUserId();  // ✅ NOT from client
        Long receiverId = Long.valueOf(payload.get("receiverId").toString());
        String name = payload.get("senderName") != null
            ? payload.get("senderName").toString()
            : "Someone";

        chatService.sendTypingIndicator(senderId, receiverId, name);
    } catch (Exception e) {
        System.err.println("WS Error in /chat.typing: " + e.getMessage());
    }
}
```

**Step 3: Add Configuration Property**

**File:** `backend/src/main/resources/application.properties`

Add at end:
```properties
# WebSocket Configuration
app.websocket.allowed-origins=${APP_WEBSOCKET_ALLOWED_ORIGINS:http://localhost:3000,http://localhost:3001}
```

**Testing:**
```bash
# Compile
mvn clean compile

# Run test - try to send message with different senderId
# Expected: Should fail or use authenticated identity
```

---

## 🔴 CRITICAL ISSUE #2: Secrets Management

**Severity:** CRITICAL  
**Impact:** Credential leakage, unauthorized API access  
**Current Status:** EXPOSED - .env in git with plaintext secrets  
**Effort:** 1-2 hours  
**Priority:** 2nd (Do immediately)

### Problem

```bash
# .env file in git with:
RAZORPAY_KEY_ID=rzp_test_SfRn4qcORkXcHX
RAZORPAY_KEY_SECRET=WJ1D68TJL2IseUcQjZTIFXnt
TWILIO_ACCOUNT_SID=AC5344d42f430cc35620949f1d5ce2d0d3
TWILIO_AUTH_TOKEN=ae8d328eb32f7708ceccd37d8b47f0f1
JWT_SECRET=CampusMart2024SecretKeyForJWTTokenGenerationMustBe256Bits!
MAIL_PASSWORD=tzvmtzlxltlqypji
DB_PASSWORD=Akash@2026
```

**Risk:** Anyone with git access has all production credentials.

### Solution

**Step 1: Create .env.local (for local dev only)**

```bash
# Create: backend/.env.local (gitignored)
# Copy contents from current .env but only for LOCAL development
# Keep .env with DUMMY values for reference
```

**Step 2: Update .gitignore**

**File:** `backend/.gitignore`

```
# Add these lines:
.env
.env.local
.env.*.local
.env.prod
*.key
*.pem
secrets/
```

**Step 3: Remove .env from Git History**

```bash
cd backend

# Remove from git tracking (doesn't delete local file)
git rm --cached .env

# Verify removal
git status

# Commit
git commit -m "security: remove .env from version control"

# For remote, force push (if collaborative repo, discuss with team)
# git push origin main --force-with-lease
```

**Step 4: Create .env.example with Dummy Values**

**File:** `backend/.env.example`

```bash
# Database Configuration
DB_PASSWORD=your_password_here

# Email Configuration
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password

# JWT Configuration
JWT_SECRET=your_jwt_secret_here_minimum_256_bits

# Twilio Configuration
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_PHONE_NUMBER=+1234567890

# Razorpay Configuration
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_secret

# Firebase Configuration
FIREBASE_PROJECT_ID=your_firebase_project
FIREBASE_PRIVATE_KEY=your_firebase_key
FIREBASE_CLIENT_EMAIL=your_firebase_email

# Notifications
NOTIFICATIONS_EMAIL_ENABLED=true
NOTIFICATIONS_PUSH_ENABLED=true
NOTIFICATIONS_FROM_EMAIL=noreply@campusmart.com

# URLs
APP_FRONTEND_BASE_URL=http://localhost:3000
APP_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
APP_WEBSOCKET_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001
```

**Step 5: Production Deployment Setup**

**For Railway (recommended):**
1. Go to Railway project settings
2. Add each secret variable in Railway UI
3. No .env file needed - Railway injects via environment

**For Render:**
1. Go to project environment variables
2. Add secrets there
3. Render injects at runtime

**For Local Development:**
```bash
# Create .env.local with your actual credentials
# Never commit this file
# java-dotenv library will automatically load it
```

**Testing:**
```bash
# Verify .env not in git
git log --all --full-history -- backend/.env
# Should show the removal commit

# Verify application.properties uses env vars
grep "RAZORPAY_KEY_ID\|JWT_SECRET" backend/src/main/resources/application.properties
# Should see: ${ENV_VAR:default}
```

---

## 🔴 CRITICAL ISSUE #3: Rate Limiting

**Severity:** CRITICAL  
**Impact:** Brute force attacks, DoS  
**Current Status:** NOT IMPLEMENTED  
**Effort:** 3-4 hours  
**Priority:** 3rd (Do this week)

### Problem

No rate limiting on:
- Login attempts (can brute force passwords)
- OTP generation (can spam)
- Payment creation (can abuse)
- Chat messages (can spam)

### Solution - Implementation

**Step 1: Add Bucket4j Dependency**

**File:** `backend/pom.xml` (in `<dependencies>` section)

```xml
<!-- Rate Limiting -->
<dependency>
    <groupId>com.github.vladimir-bukhtoyarov</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>7.6.0</version>
</dependency>
```

**Step 2: Create Rate Limiting Utility**

**File:** `backend/src/main/java/com/campusmart/util/RateLimiter.java`

```java
package com.campusmart.util;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Bucket4j;
import io.github.bucket4j.Refill;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class RateLimiter {

    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();

    // Login: 5 attempts per minute per IP
    public boolean allowLogin(String ipAddress) {
        return allowRequest(ipAddress + ":login", 5, Duration.ofMinutes(1));
    }

    // OTP: 3 attempts per 30 minutes per phone
    public boolean allowOtpGenerate(String phone) {
        return allowRequest(phone + ":otp", 3, Duration.ofMinutes(30));
    }

    // Payment: 10 attempts per minute per user
    public boolean allowPaymentCreate(String userId) {
        return allowRequest(userId + ":payment", 10, Duration.ofMinutes(1));
    }

    // Chat: 100 messages per minute per user
    public boolean allowChat(String userId) {
        return allowRequest(userId + ":chat", 100, Duration.ofMinutes(1));
    }

    private boolean allowRequest(String key, long tokens, Duration refillDuration) {
        Bucket bucket = cache.computeIfAbsent(key, k -> 
            Bucket4j.builder()
                .addLimit(Bandwidth.classic(tokens, Refill.intervally(tokens, refillDuration)))
                .build()
        );
        
        return bucket.tryConsume(1);
    }
}
```

**Step 3: Add Rate Limiting to Controllers**

**File:** `backend/src/main/java/com/campusmart/controller/AuthController.java`

```java
@Autowired
private RateLimiter rateLimiter;

// Get IP from request
private String getClientIp(HttpServletRequest request) {
    String xForwardedFor = request.getHeader("X-Forwarded-For");
    if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
        return xForwardedFor.split(",")[0];
    }
    return request.getRemoteAddr();
}

@PostMapping("/login")
public ResponseEntity<?> login(
        @RequestBody Map<String, String> body,
        HttpServletRequest request) {
    
    String ipAddress = getClientIp(request);
    
    // Rate limit: 5 attempts per minute per IP
    if (!rateLimiter.allowLogin(ipAddress)) {
        return ResponseEntity
            .status(429)  // Too Many Requests
            .body(Map.of("error", "Too many login attempts. Try again in 1 minute."));
    }

    // ... rest of login logic
}
```

**Do same for:**
- OtpController - POST /api/otp/generate
- PaymentController - POST /api/payments/create-order
- ChatController - POST /api/chat/send

**Testing:**
```bash
# Try login 6 times rapidly
curl -X POST http://localhost:8081/api/auth/login ...
# 6th attempt should return 429 Too Many Requests

# Wait 1 minute, try again
# Should succeed (bucket refilled)
```

---

## 🔴 CRITICAL ISSUE #4: Database Migration Strategy

**Severity:** CRITICAL  
**Impact:** Schema evolution, production safety  
**Current Status:** Using ddl-auto=update (UNSAFE)  
**Effort:** 2-3 hours  
**Priority:** 4th (Do this week)

### Problem

```properties
spring.jpa.hibernate.ddl-auto=update  # ❌ Can corrupt schema
```

This can cause:
- Unexpected schema changes in production
- Data loss on bad migrations
- Inconsistent state between environments

### Solution - Flyway Implementation

**Step 1: Add Flyway Dependency**

**File:** `backend/pom.xml`

```xml
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>

<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-mysql</artifactId>
</dependency>
```

**Step 2: Change Hibernate Config**

**File:** `backend/src/main/resources/application.properties`

```properties
# OLD:
# spring.jpa.hibernate.ddl-auto=update

# NEW - Let Flyway handle migrations:
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.hibernate.dialect=org.hibernate.dialect.MySQLDialect
```

**Step 3: Create Initial Schema Migration**

**File:** `backend/src/main/resources/db/migration/V1__initial_schema.sql`

```sql
-- This file contains the current schema
-- Run: mvn flyway:migrate

-- You'll need to export current schema:
-- From MySQL: mysqldump -u root -p campus_mart --no-data > V1__initial_schema.sql
```

**Step 4: Test Migration**

```bash
cd backend

# Validate Flyway config
mvn flyway:info
# Should show: V1__initial_schema.sql (Pending)

# Run migration
mvn flyway:migrate
# Should show: Successfully applied 1 migration

# Verify schema matches
mvn flyway:validate
# Should show: Success
```

---

## 🔴 CRITICAL ISSUE #5: Database Indexes & N+1 Queries

**Severity:** CRITICAL  
**Impact:** Severe performance degradation at scale  
**Current Status:** No indexes, N+1 queries in code  
**Effort:** 4-5 hours  
**Priority:** 5th (Do this week)

### Problem

```sql
-- MISSING INDEXES on frequently queried columns:
-- items (seller_id, status, category_id, created_at)
-- messages (sender_id, receiver_id)
-- payment_orders (buyer_id, status)
-- students (email, phone)

-- N+1 Query Example:
List<Item> items = itemRepo.findAll();  // 1 query, 1000 items
for (Item item : items) {
    Student seller = item.getSeller();  // +1000 queries! ❌
}
```

### Solution

**Step 1: Add Database Indexes**

**File:** `backend/src/main/resources/db/migration/V2__add_indexes.sql`

```sql
-- Students indexes
ALTER TABLE students ADD UNIQUE INDEX idx_email (email);
ALTER TABLE students ADD INDEX idx_phone (phone);
ALTER TABLE students ADD INDEX idx_role (role);
ALTER TABLE students ADD INDEX idx_college_id (college_id);

-- Items indexes
ALTER TABLE items ADD INDEX idx_seller_id (seller_id);
ALTER TABLE items ADD INDEX idx_status (status);
ALTER TABLE items ADD INDEX idx_category_id (category_id);
ALTER TABLE items ADD INDEX idx_created_at (created_at DESC);
ALTER TABLE items ADD INDEX idx_search (title, description);

-- Messages indexes
ALTER TABLE messages ADD INDEX idx_sender_receiver (sender_id, receiver_id);
ALTER TABLE messages ADD INDEX idx_created_at (created_at DESC);

-- Payment orders indexes
ALTER TABLE payment_orders ADD INDEX idx_buyer_id (buyer_id);
ALTER TABLE payment_orders ADD INDEX idx_seller_id (seller_id);
ALTER TABLE payment_orders ADD INDEX idx_status (status);

-- Reports indexes
ALTER TABLE reports ADD INDEX idx_status_created (status, created_at DESC);
ALTER TABLE reports ADD INDEX idx_reporter_id (reporter_id);

-- Wishlists indexes
ALTER TABLE wishlists ADD INDEX idx_student_item (student_id, item_id);
```

**Step 2: Fix N+1 Queries in Code**

**File:** `backend/src/main/java/com/campusmart/repository/ItemRepository.java`

```java
// OLD - Causes N+1 queries:
List<Item> findAll();

// NEW - Fetch with seller in single query:
@Query("SELECT i FROM Item i JOIN FETCH i.seller WHERE i.status = :status")
List<Item> findAvailableItemsWithSeller(@Param("status") ItemStatus status);
```

**Fix in ItemService:**
```java
// OLD:
List<Item> items = itemRepository.findAll();
// SQL: 1 query for items, +1000 queries for sellers

// NEW:
List<Item> items = itemRepository.findAvailableItemsWithSeller(ItemStatus.AVAILABLE);
// SQL: 1 query with JOIN FETCH
```

**Step 3: Remove EAGER Loading**

**File:** `backend/src/main/java/com/campusmart/model/Item.java`

```java
// OLD:
@ManyToOne(fetch = FetchType.EAGER)
private Student seller;

// NEW:
@ManyToOne(fetch = FetchType.LAZY)
private Student seller;
```

Do same for:
- Item.category
- Item.images
- Message.sender
- PaymentOrder.item

**Step 4: Test Performance**

```bash
# Before indexes - time a query with 1000 items
time curl http://localhost:8081/api/items/paginated?page=0&pageSize=1000
# Result: ~3-5 seconds (slow)

# Add indexes via:
mvn flyway:migrate

# After indexes
time curl http://localhost:8081/api/items/paginated?page=0&pageSize=1000
# Result: ~200-400 ms (10x faster)
```

---

## Phase 2 Summary

| Issue | Status | Effort | Priority |
|-------|--------|--------|----------|
| WebSocket Security | Ready to implement | 2-3 hrs | 1 |
| Secrets Management | Ready to implement | 1-2 hrs | 2 |
| Rate Limiting | Ready to implement | 3-4 hrs | 3 |
| Database Migrations | Ready to implement | 2-3 hrs | 4 |
| Database Indexes & N+1 | Ready to implement | 4-5 hrs | 5 |
| **TOTAL** | | **12-17 hrs** | |

---

## Implementation Order

**Day 1:**
- Fix WebSocket security
- Implement rate limiting
- Total: 5-7 hours

**Day 2:**
- Remove secrets from git
- Setup production secrets
- Total: 1-2 hours

**Day 3:**
- Setup Flyway migrations
- Add database indexes
- Fix N+1 queries
- Total: 6-8 hours

**By end of Week 1:** Phase 2 Complete → Score: 65-70%

---

## Verification Checklist (Before Phase 3)

```bash
# 1. WebSocket uses JWT identity
grep -r "SecurityUtils.getCurrentUserId()" backend/src/main/java/com/campusmart/controller/ChatController.java
# Expected: Found in handleMessage() and handleTyping()

# 2. Secrets not in git
git log --all --full-history -- backend/.env
# Expected: Removal commit shown

# 3. Rate limiter in place
mvn clean compile | grep -i "RateLimiter"
# Expected: Compiles without errors

# 4. Migrations setup
ls -la backend/src/main/resources/db/migration/
# Expected: V1__initial_schema.sql, V2__add_indexes.sql

# 5. Flyway applied
mvn flyway:info | grep -i "success"
# Expected: Shows applied migrations

# 6. Compile & test
mvn clean compile
mvn test
# Expected: BUILD SUCCESS, Tests run: 5+, Failures: 0
```

---

## Next: Phase 3

Once Phase 2 is 100% complete:

- File upload security hardening
- Image storage (S3 integration)
- Error handling framework
- JWT refresh tokens
- Production logging setup

Target: **70-75%** readiness score


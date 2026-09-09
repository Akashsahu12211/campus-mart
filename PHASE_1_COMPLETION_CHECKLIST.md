# PHASE 1 - SECURITY HARDENING - COMPLETION CHECKLIST

**Target:** Fully secure authorization using JWT identity + SecurityUtils  
**Status:** In Progress (85% complete)  
**Last Updated:** April 27, 2026

---

## ✅ VERIFIED - Already In Place

### Core Infrastructure
- [x] SecurityUtils.java - Centralized identity extraction from JWT
- [x] AuthorizationFilter.java - Request authentication filter
- [x] JwtUtil.java - JWT token generation & validation
- [x] AuthenticatedStudent.java - Wraps student with authorities
- [x] Spring Security config - @EnableWebSecurity + @EnableMethodSecurity
- [x] SecurityConfig.java - Proper role-based access rules

### Implementation in Controllers
- [x] OfferController - Uses SecurityUtils.getCurrentUserId()
- [x] ChatController - Has requireSameUser() validation
- [x] ItemController - Uses OwnershipValidator
- [x] PaymentController - Validates buyerId matches authenticated user
- [x] AdminController - @PreAuthorize("hasRole('ADMIN')") at class level
- [x] WishlistController - validateCurrentUser() method

### Utilities
- [x] OwnershipValidator.java - Consistent ownership checks

---

## ⚠️ PARTIALLY DONE - Needs Completion

### 1. CORS Configuration
**Status:** Partially hardcoded

**Files to Update:**
- [ ] AdminController - @CrossOrigin needs environment variable
- [ ] ItemController - @CrossOrigin needs environment variable
- [ ] OfferController - @CrossOrigin(origins = "*") should be restricted
- [ ] ChatController - @CrossOrigin needs environment variable
- [ ] PaymentController - @CrossOrigin needs environment variable

**Current:**
```java
@CrossOrigin(origins = {"http://localhost:3000", "http://localhost:3001"})
```

**Should Be:**
```java
// Remove @CrossOrigin from controllers, use CorsConfig instead
// Or inject environment variable
@Value("${app.cors.allowed-origins}")
private String[] allowedOrigins;
```

### 2. WebSocket Security
**Status:** Critical gap

**Issue:**
```java
// WebSocketConfig.java - Line ~25
.setAllowedOriginPatterns("*")  // 🔴 ALLOWS ANY ORIGIN
```

**Should Be:**
```java
@Value("${app.websocket.allowed-origins:http://localhost:3000,http://localhost:3001}")
private String allowedOrigins;

// In registerStompEndpoints:
String[] origins = allowedOrigins.split(",");
registry.addEndpoint("/ws")
    .setAllowedOrigins(origins)  // Restrict to specific origins
    .withSockJS();
```

**Additional Issue:** senderId from client not validated against JWT identity

```java
// ChatController.java - sendMessage() endpoint
Long senderId = Long.valueOf(payload.get("senderId").toString());
// SHOULD BE:
Long senderId = SecurityUtils.getCurrentUserId();  // From JWT, not client
```

### 3. Request Parameter Validation
**Status:** Needs Standardization

**Endpoints that should validate ownership:**
- [ ] POST /api/items - Verify seller is authenticated user
- [ ] PUT /api/items/{id} - Verify owner
- [ ] DELETE /api/items/{id} - Verify owner
- [ ] PATCH /api/items/{id}/reserve - Verify reserver is authenticated
- [ ] PATCH /api/items/{id}/unreserve - Verify reserver is authenticated
- [ ] PATCH /api/items/{id}/sold - Verify owner is authenticated

**Pattern to Use:**
```java
Long userId = SecurityUtils.getCurrentUserId();  // From JWT
// Then verify: userId == item.getSeller().getId()
```

### 4. All Endpoints Need @PreAuthorize or Manual Check

**Review Needed:**
- [ ] StudentController - Verify profile endpoints check ownership
- [ ] ReviewController - Verify review creation validates ownership
- [ ] SupportController - Verify support ticket access
- [ ] NotificationController - Verify notification access
- [ ] ReportController - Verify report ownership
- [ ] TransactionController - Verify transaction access

---

## 🔴 NOT YET DONE - Critical Gaps

### 1. Rate Limiting
**Status:** Not implemented

**Endpoints needing rate limiting:**
- [ ] POST /api/auth/login - 5 attempts/minute per IP
- [ ] POST /api/students/register - 1 attempt/hour per email
- [ ] POST /api/otp/generate - 3 attempts/30 min per phone
- [ ] POST /api/payments/create-order - 10 attempts/min per user
- [ ] POST /api/chat/send - 100 messages/min per user

**Implementation:** Need to add Spring Cloud Sleuth or use custom RateLimitFilter

### 2. Database Secrets Management
**Status:** Exposed in .env

**Issue:**
```env
# .env - SHOULD NOT BE IN GIT
RAZORPAY_KEY_ID=rzp_test_SfRn4qcORkXcHX
RAZORPAY_KEY_SECRET=WJ1D68TJL2IseUcQjZTIFXnt
TWILIO_ACCOUNT_SID=AC5344d42f430cc35620949f1d5ce2d0d3
JWT_SECRET=CampusMart2024SecretKeyForJWTTokenGenerationMustBe256Bits!
```

**Must Do:**
- [ ] Remove .env from git history (git rm --cached .env)
- [ ] Add .env to .gitignore
- [ ] Create .env.example with dummy values
- [ ] Use environment variables in production

### 3. JWT Token Expiry
**Status:** Too long (7 days)

**Current:** `jwt.expiry.ms=604800000` (7 days)

**Should Be:**
- Access token: 15 minutes
- Refresh token: 7 days with rotation

---

## 📋 PHASE 1 COMPLETION TASKS

### Task 1: Standardize Identity Validation Across All Controllers [2 hours]
**Checklist:**
- [ ] Audit all 13 controllers
- [ ] Replace custom validation with SecurityUtils.getCurrentUserId()
- [ ] Replace direct ID parameters with JWT identity where appropriate
- [ ] Add verification test for each controller
- [ ] Compile and test

### Task 2: Fix CORS Configuration [1.5 hours]
**Checklist:**
- [ ] Add app.cors.allowed-origins to application.properties
- [ ] Update all @CrossOrigin annotations to use environment variable or remove
- [ ] Verify CorsConfig.java uses env variable
- [ ] Test CORS headers in responses
- [ ] Compile

### Task 3: Fix WebSocket CORS and Identity [2 hours]
**Checklist:**
- [ ] Update WebSocketConfig to use allowed-origins from environment
- [ ] Fix ChatController to validate senderId against JWT
- [ ] Update ChatService to use authenticated identity
- [ ] Add integration test for WebSocket auth
- [ ] Compile and test chat flow

### Task 4: Add Input Validation Framework [3 hours]
**Checklist:**
- [ ] Create request DTOs for critical endpoints
- [ ] Add @NotNull, @NotBlank, @Positive annotations
- [ ] Create global validation exception handler
- [ ] Test validation with invalid inputs
- [ ] Compile

### Task 5: Create Phase 1 Security Test Suite [4 hours]
**Checklist:**
- [ ] Create test for admin authorization checks
- [ ] Create test for ownership validation
- [ ] Create test for WebSocket authentication
- [ ] Create test for JWT validation
- [ ] Create test for CORS origin restrictions
- [ ] Run full test suite: mvn test
- [ ] Verify: Tests run: 5-10, Failures: 0

### Task 6: Documentation & Handoff [1 hour]
**Checklist:**
- [ ] Create PHASE_1_IMPLEMENTATION_GUIDE.md
- [ ] Document all security changes
- [ ] Create PHASE_2_PREREQUISITES.md
- [ ] Create deployment checklist

---

## Effort Estimate

| Task | Hours | Priority |
|------|-------|----------|
| Standardize Identity Validation | 2 | CRITICAL |
| Fix CORS Configuration | 1.5 | CRITICAL |
| Fix WebSocket Security | 2 | CRITICAL |
| Add Input Validation | 3 | HIGH |
| Test Suite Creation | 4 | HIGH |
| Documentation | 1 | MEDIUM |
| **TOTAL** | **13.5** | |

**Timeline:** 2-3 days with focused effort

---

## Success Criteria

✅ All controllers use SecurityUtils for identity  
✅ CORS only allows configured origins  
✅ WebSocket validates JWT identity  
✅ All sensitive endpoints have ownership checks  
✅ 5+ integration tests passing  
✅ Zero authorization bypass vulnerabilities  
✅ mvn clean compile → BUILD SUCCESS  

---

## Verification Checklist (Before Moving to Phase 2)

Run these commands to verify Phase 1 is complete:

```bash
# 1. Check for direct ID parameters
grep -r "request.getAttribute.*Id" backend/src/main/java/com/campusmart/controller/

# 2. Check SecurityUtils usage
grep -r "SecurityUtils.getCurrentUserId()" backend/src/main/java/com/campusmart/controller/ | wc -l
# Expected: 10+

# 3. Compile backend
cd backend
mvn clean compile
# Expected: BUILD SUCCESS

# 4. Run tests
mvn test
# Expected: Tests run: 5+, Failures: 0

# 5. Check for localhost in production configs
grep -r "localhost" backend/src/main/resources/application.properties
# Expected: Only in fallback defaults, not hardcoded

# 6. Verify @CrossOrigin not hardcoded
grep -r "@CrossOrigin.*origins.*localhost" backend/src/
# Expected: 0 matches (should use env var instead)
```

---

## Next Steps After Phase 1 Complete

Once this checklist is 100% complete:

→ Move to **PHASE 2: Critical Security & Performance Fixes**
1. Rate limiting implementation
2. Secrets management (remove from git)
3. Database migration (Flyway)
4. WebSocket socket binding
5. File upload security

→ Target score: **65-70%** (from 58%)

---

## Notes

- **Do not skip test creation** - it catches regressions
- **Test in dev environment first** - before deploying
- **Review each change** - security requires careful implementation
- **Ask questions** - if anything is unclear, verify understanding first


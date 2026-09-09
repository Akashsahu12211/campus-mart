# NEXT SESSION QUICK START GUIDE

**Last Updated:** April 27, 2026  
**Status:** Ready for Phase 2c Controller Integration  
**Estimated Time:** 6-8 hours to completion

---

## TL;DR - Start Here

### Current State
✅ Phase 1: All security fixes complete and compiled
✅ Phase 2a: Database migrations ready (Flyway)
✅ Phase 2b: Rate limiting utility ready
⏳ Phase 2c: Need to add rate limiting to 5 controllers
⏳ Phase 2d: Need to clean secrets from git

### Build Status
```bash
cd backend
mvn clean compile  # ✅ BUILD SUCCESS
```

---

## SESSION 1 - IMMEDIATE NEXT (6-8 HOURS)

### Step 1: AuthController Integration (1-2 hours)

**File:** `backend/src/main/java/com/campusmart/controller/AuthController.java`

**Quick Reference:**
```java
// Add imports
import com.campusmart.util.RateLimiter;
import com.campusmart.util.ServletUtils;
import jakarta.servlet.http.HttpServletRequest;

// Add field
@Autowired private RateLimiter rateLimiter;

// Modify 4 methods to add rate limiting:
// 1. @PostMapping("/login") - Add IP-based check
// 2. @PostMapping("/register") - Add email-based check
// 3. @PostMapping("/verify-email") - Add email-based check
// 4. @PostMapping("/forgot-password/request") - Add email-based check
```

**Detailed guide:** See `PHASE_2_INTEGRATION_GUIDE.md` (AuthController section)

### Step 2: PaymentController Integration (30 min)

**File:** `backend/src/main/java/com/campusmart/controller/PaymentController.java`

Add rate limiting to order creation endpoint:
```java
// Add check before creating order:
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateOrder(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of("error", "Too many orders. Try again later."));
}
```

### Step 3: ItemController Integration (30 min)

Add rate limiting to item creation:
```java
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateItem(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of("error", "Item limit reached."));
}
```

### Step 4: ChatController Integration (30 min)

Add rate limiting to message sending:
```java
if (!rateLimiter.allowSendMessage(senderId.toString())) {
    throw new RuntimeException("Message rate limit exceeded.");
}
```

### Step 5: OfferController Integration (30 min)

Add rate limiting to offer creation:
```java
Long userId = SecurityUtils.getCurrentUserId();
if (!rateLimiter.allowCreateOffer(userId.toString())) {
    return ResponseEntity.status(429).body(Map.of("error", "Offer limit reached."));
}
```

### Step 6: Verification (1 hour)

```bash
# Compile
mvn clean compile  # Should: BUILD SUCCESS

# Run tests
mvn test

# Test manually
for i in {1..6}; do
  curl -X POST http://localhost:8081/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"wrong"}'
  echo "Request $i"
done
# Expected: Requests 1-5 return 401, Request 6 returns 429
```

---

## SESSION 2 - SECRETS CLEANUP (1-2 HOURS)

### Step 1: Create .env.example

**File:** `backend/.env.example`

Copy template from `PHASE_2_INTEGRATION_GUIDE.md` (Secrets section)

### Step 2: Update .gitignore

**File:** `backend/.gitignore`

Add line:
```
.env
```

### Step 3: Clean Git History

```bash
cd backend
git rm --cached .env
git add .gitignore .env.example
git commit -m "security: remove .env from version control"
git push origin main
```

### Step 4: Setup on Platforms

- **Railway:** Add each variable in dashboard
- **Render:** Add to Environment section
- **AWS:** Use Secrets Manager

---

## SESSION 3 - TESTING (4-5 HOURS)

Create comprehensive test suite:

```bash
# Create test file
src/test/java/com/campusmart/security/RateLimitingTest.java

# Tests needed:
- Login rate limit: 5 attempts succeed, 6th fails
- OTP rate limit: 3 attempts succeed, 4th fails
- Order creation: 10 succeed, 11th fails
- IP extraction: Proxy headers, direct connections
- Error responses: 429 status code, correct message

# Run tests
mvn test
```

---

## FILES TO REFERENCE

| File | Purpose |
|------|---------|
| `PHASE_2_INTEGRATION_GUIDE.md` | Step-by-step controller modifications |
| `PHASE_2_PROGRESS.md` | Current session progress |
| `src/main/java/com/campusmart/util/RateLimiter.java` | Rate limiter implementation |
| `src/main/java/com/campusmart/util/ServletUtils.java` | IP extraction utility |
| `src/main/resources/db/migration/V1__initial_schema.sql` | Database schema |

---

## VERIFICATION CHECKLIST

Before moving to next phase:

- [ ] AuthController rate limiting added to 4 methods
- [ ] PaymentController rate limiting added
- [ ] ItemController rate limiting added
- [ ] ChatController rate limiting added
- [ ] OfferController rate limiting added
- [ ] All code compiles: `mvn clean compile`
- [ ] All tests pass: `mvn test`
- [ ] .env.example created
- [ ] .env removed from git
- [ ] Environment variables configured on deployment platforms

---

## COMPILATION COMMANDS

```bash
# Quick compile check
cd backend && mvn clean compile -q && echo "BUILD SUCCESS"

# With test
cd backend && mvn clean compile && mvn test

# Skip tests (for quick builds)
cd backend && mvn clean compile -DskipTests
```

---

## READINESS SCORE AFTER COMPLETION

**Current:** 58% (start of session)  
**Phase 1 Complete:** ~62%  
**Phase 2 Complete:** ~75%  
**Target:** 85%+

**Progress:** 58% → 75% is 29% improvement towards target!

---

## COMMON ISSUES & SOLUTIONS

### Issue: "RateLimiter not found" error
**Solution:** Make sure `@Autowired private RateLimiter rateLimiter;` is added to controller

### Issue: "SecurityUtils not found" error
**Solution:** Already implemented, just needs import: `import com.campusmart.config.SecurityUtils;`

### Issue: Rate limit check not working
**Solution:** Ensure `if (!rateLimiter.allow...())` returns early with 429 status

### Issue: Git rm --cached fails
**Solution:** Ensure .env exists in root, not nested in subdirectory

---

## ESTIMATED HOUR BREAKDOWN

| Task | Hours |
|------|-------|
| AuthController (4 methods) | 1.5 |
| PaymentController | 0.5 |
| ItemController | 0.5 |
| ChatController | 0.5 |
| OfferController | 0.5 |
| Testing & verification | 1.5 |
| **Controller Integration Total** | **5.5** |
| Secrets cleanup | 1.5 |
| Test suite creation | 4 |
| **Grand Total (Phase 2 remaining)** | **11 hours** |

---

## SUCCESS CRITERIA

✅ Session complete when:
1. All 5 controllers have rate limiting integrated
2. Code compiles: `mvn clean compile`
3. Tests pass: `mvn test`
4. .env removed from git
5. Environment variables configured
6. Security score improved to ~75%

---

## NEXT PHASES (AFTER PHASE 2)

**Phase 3 (1 week):**
- Global error handling
- Structured logging
- Health endpoints

**Phase 4 (1-2 weeks):**
- File upload security
- S3 integration
- JWT refresh tokens
- Test coverage 30%+

---

**Ready to begin?** Start with AuthController in `PHASE_2_INTEGRATION_GUIDE.md`


# Campus Mart - Security Hardening Roadmap

**Goal:** Move from 58% → 85%+ (Production Ready)  
**Timeline:** 4 weeks  
**Status:** Phase 1 Started, Ready for Phase 2

---

## 📊 Score Progression Target

```
Current:        58% (Functional but not production ready)
After Phase 1:  62-65% (Better authorization)
After Phase 2:  68-72% (Secure infrastructure)
After Phase 3:  78-82% (Operations & monitoring)
After Phase 4:  85%+ (Production ready)
```

---

## 🎯 PHASE 1: Complete Authorization Security (2-3 days)

### Objective
Ensure every sensitive operation validates user identity from JWT, not request parameters.

### Tasks
1. ✅ Standardize identity validation across all 13 controllers
2. ✅ Fix CORS configuration (environment variables)
3. ✅ Fix WebSocket CORS (environment variables)
4. ✅ Create input validation framework (DTOs)
5. ✅ Create comprehensive security test suite

### Deliverables
- [ ] PHASE_1_COMPLETION_CHECKLIST.md - CREATED ✅
- [ ] All controllers use SecurityUtils.getCurrentUserId()
- [ ] 5+ integration tests passing
- [ ] mvn clean compile → BUILD SUCCESS

### Effort
- **13.5 hours** (~2-3 days)
- Per person: 1-2 days focused work

### Success Criteria
- Zero authorization bypass vulnerabilities
- All ownership checks validated
- WebSocket validates JWT identity

---

## 🔴 PHASE 2: Critical Infrastructure Fixes (1-2 weeks)

### Objective
Fix 5 blocking security issues that prevent any production launch.

### Tasks
1. 🔴 **WebSocket Security** (2-3 hrs)
   - Restrict CORS to configured origins
   - Validate senderId against JWT identity
   - Add integration test

2. 🔴 **Secrets Management** (1-2 hrs)
   - Remove .env from git history
   - Create .env.example
   - Setup production secrets management

3. 🔴 **Rate Limiting** (3-4 hrs)
   - Add Bucket4j dependency
   - Implement RateLimiter utility
   - Apply to auth, OTP, payment, chat endpoints

4. 🔴 **Database Migrations** (2-3 hrs)
   - Add Flyway dependency
   - Create initial schema migration
   - Setup migration validation

5. 🔴 **Database Indexes & Performance** (4-5 hrs)
   - Add critical indexes
   - Fix N+1 queries
   - Remove EAGER loading

### Deliverables
- [ ] PHASE_2_CRITICAL_FIXES.md - CREATED ✅
- [ ] WebSocket properly authenticated
- [ ] Secrets secured (not in git)
- [ ] Rate limiting on critical endpoints
- [ ] Database migrations working
- [ ] Query performance improved 10x

### Effort
- **12-17 hours** (~1-2 weeks)
- Days 1-2: WebSocket + Secrets (3 hrs)
- Days 3-4: Rate Limiting + Migrations (5 hrs)
- Days 5-7: Database optimization (6 hrs)

### Success Criteria
- ✅ No SQL injection risks
- ✅ Rate limiting prevents abuse
- ✅ Flyway migrations validate schema
- ✅ Indexes improve query performance 10x

---

## ⚠️ PHASE 3: Operations & Monitoring (1 week)

### Objective
Add observability, error handling, and operational readiness.

### Tasks
1. **Production Logging** (3-4 hrs)
   - Add Logback + SLF4J
   - Structure logs for production
   - Setup log aggregation

2. **Error Handling Framework** (3-4 hrs)
   - Create @ControllerAdvice
   - Standardized error responses
   - HTTP status code mapping

3. **Health Checks** (2 hrs)
   - Add Spring Boot Actuator
   - Create /health endpoint
   - Database connection checks

4. **Deployment Configuration** (2 hrs)
   - Remove hardcoded localhost URLs
   - Environment-specific config
   - Production profiles

5. **API Documentation** (2 hrs)
   - Swagger/OpenAPI setup
   - Endpoint documentation

### Deliverables
- [ ] Structured logging in place
- [ ] Global error handler
- [ ] Health check working
- [ ] Deployable to Render/Railway

### Effort
- **12-14 hours** (~1 week)

### Success Criteria
- ✅ Can debug production issues via logs
- ✅ Consistent API error responses
- ✅ Can monitor service health
- ✅ Deployable to cloud platforms

---

## 🚀 PHASE 4: Final Hardening (1 week)

### Objective
Performance optimization, file upload security, and testing.

### Tasks
1. **File Upload Security** (3-4 hrs)
   - MIME type validation
   - File size limits
   - Clean up abandoned uploads

2. **Image Storage (S3)** (4-5 hrs)
   - AWS S3 integration
   - Pre-signed URLs
   - CDN setup (optional)

3. **JWT Refresh Tokens** (2-3 hrs)
   - Implement refresh endpoint
   - Token rotation
   - Session invalidation

4. **Comprehensive Testing** (8+ hrs)
   - Auth flow tests
   - Payment flow tests
   - Admin authorization tests
   - Chat authorization tests

5. **Security Audit** (2-3 hrs)
   - Penetration testing
   - Vulnerability scan
   - Final security review

### Deliverables
- [ ] File uploads secure
- [ ] Images on S3
- [ ] Refresh token working
- [ ] 30%+ test coverage
- [ ] Security audit passed

### Effort
- **20-25 hours** (~1 week focused)

### Success Criteria
- ✅ No MIME attack vectors
- ✅ Images served via CDN
- ✅ Secure session management
- ✅ Critical paths tested

---

## 📅 Timeline

```
Week 1 (Apr 28 - May 4)
├── Day 1-2: Phase 1 complete (13.5 hrs)
│   ├── Standardize identity validation
│   ├── Fix CORS
│   └── Security tests
├── Day 3-5: Phase 2 partial (7-8 hrs)
│   ├── WebSocket security
│   ├── Secrets management
│   └── Rate limiting started
└── Goal: Phase 1 ✅, 60-65% score

Week 2 (May 5 - May 11)
├── Day 1-2: Phase 2 complete (5-7 hrs)
│   ├── Rate limiting finished
│   ├── Flyway migrations
│   └── Database indexes
├── Day 3-5: Phase 3 started (5-6 hrs)
│   ├── Logging setup
│   ├── Error handling
│   └── Health checks
└── Goal: Phase 2 ✅, 68-72% score

Week 3 (May 12 - May 18)
├── Day 1-2: Phase 3 complete (6-8 hrs)
│   ├── Deployment config
│   ├── API documentation
│   └── Production profiles
├── Day 3-5: Phase 4 partial (8 hrs)
│   ├── File upload security
│   ├── S3 integration started
│   └── Testing begun
└── Goal: Phase 3 ✅, 75-78% score

Week 4 (May 19 - May 25)
├── Day 1-3: Phase 4 complete (10+ hrs)
│   ├── S3 images
│   ├── Refresh tokens
│   ├── Comprehensive tests
│   └── Security audit
├── Day 4-5: Final verification
│   ├── End-to-end testing
│   ├── Performance testing
│   └── Production readiness check
└── Goal: Phase 4 ✅, 85%+ score ✅ LAUNCH READY
```

---

## 💼 Resource Allocation

### Minimum Team (for 4 weeks)
- **1 Backend Engineer** - 40 hrs/week (ALL phases)
- **1 QA Engineer** - 20 hrs/week (Testing)
- **Optional: DevOps** - 10 hrs/week (Deployment setup)

### If Solo Developer
- **Week 1-2**: Focus on Phase 1 + 2 (critical)
- **Week 3-4**: Phase 3 + 4 (can stretch)
- **Total:** 60-70 hours concentrated work

---

## 📋 Dependencies Between Phases

```
Phase 1 ✅ (Must complete first)
    ↓ (All controllers must be secure before moving forward)
Phase 2 ⚠️ (Can start after Phase 1 verification)
    ↓ (Secrets and migrations needed for Phase 3)
Phase 3 ⚠️ (Can start after Phase 2 verification)
    ↓ (Monitoring needed before Phase 4)
Phase 4 🚀 (Final hardening)
    ↓ (Testing verifies everything works)
PRODUCTION READY ✅ (85%+ score)
```

---

## ✅ Definition of Done

### Phase 1 Complete When:
- [ ] All controllers use SecurityUtils.getCurrentUserId()
- [ ] CORS restricted to env variables
- [ ] WebSocket validates JWT
- [ ] 5+ integration tests passing
- [ ] mvn clean compile → BUILD SUCCESS
- [ ] Code review: 2 developers approved

### Phase 2 Complete When:
- [ ] WebSocket authentication working in staging
- [ ] .env removed from git, secrets in platform
- [ ] Rate limiting tested (429 response on excess)
- [ ] Flyway migrations apply without error
- [ ] Query performance improved 10x+ on large datasets

### Phase 3 Complete When:
- [ ] Logs appear in production dashboard
- [ ] Error responses consistent across API
- [ ] /health endpoint returns 200
- [ ] Deployed to Railway/Render successfully

### Phase 4 Complete When:
- [ ] File uploads validated for MIME type
- [ ] Images serving from S3
- [ ] Refresh token rotates on each use
- [ ] Test coverage ≥ 30% for critical paths
- [ ] Security audit report: 0 critical issues

---

## 🎯 Go/No-Go Decision Points

### After Phase 1 (Day 3)
**Go if:**
- ✅ All authorization tests passing
- ✅ No hardcoded IDs in requests
- ✅ mvn clean compile SUCCESS

**No-Go if:**
- ❌ Authorization bypasses found
- ❌ Compilation errors remain

### After Phase 2 (Day 8)
**Go if:**
- ✅ No secrets in git history
- ✅ Rate limiting working
- ✅ Database indexes applied
- ✅ Flyway migrations successful

**No-Go if:**
- ❌ Secrets still exposed
- ❌ Performance not improved

### After Phase 3 (Day 14)
**Go if:**
- ✅ Staging environment working
- ✅ Logs aggregating properly
- ✅ Health checks passing

**No-Go if:**
- ❌ Deployment issues
- ❌ Error handling incomplete

### After Phase 4 (Day 21+)
**Go if:**
- ✅ 30%+ test coverage
- ✅ Security audit passed
- ✅ Score ≥ 85%
- ✅ No critical vulnerabilities

**No-Go if:**
- ❌ Test coverage < 20%
- ❌ Critical security issues
- ❌ Score < 80%

---

## 🚨 Critical Milestones

| Milestone | Date | Target | Status |
|-----------|------|--------|--------|
| Phase 1 Complete | Day 3 | 62-65% | Not Started |
| Phase 2 Complete | Day 8 | 68-72% | Not Started |
| Phase 3 Complete | Day 14 | 75-78% | Not Started |
| Phase 4 Complete | Day 21 | 85%+ | Not Started |
| **PRODUCTION READY** | **Day 28** | **85%+** | **Ready for launch** |

---

## 📞 Support & Escalation

### If Stuck:
1. Check the detailed implementation file for that phase
2. Review error messages carefully
3. Search GitHub issues for similar problems
4. Ask for clarification before proceeding

### Risk Areas (Plan Extra Time):
- Database migrations on existing data (Week 2)
- S3 integration testing (Week 3-4)
- Test coverage expansion (Week 4)

---

## 🎓 Learning Resources

### Phase 1 - Authorization
- Spring Security docs: https://spring.io/projects/spring-security
- JWT best practices: https://tools.ietf.org/html/rfc8725

### Phase 2 - Infrastructure
- Bucket4j rate limiting: https://github.com/vladimir-bukhtoyarov/bucket4j
- Flyway migrations: https://flywaydb.org/documentation/

### Phase 3 - Operations
- Logback configuration: http://logback.qos.ch/
- Spring Actuator: https://spring.io/guides/gs/actuator-service/

### Phase 4 - Security
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- AWS S3 security: https://docs.aws.amazon.com/s3/

---

## 📊 Success Metrics

```
Metric                          | Current | Target
─────────────────────────────────┼─────────┼────────
Readiness Score                 | 58%     | 85%+
Authorization Coverage          | 60%     | 100%
Test Coverage (Critical)        | 1%      | 30%+
Query Performance (avg)         | 3-5s    | 200-400ms
Security Issues (critical)      | 5       | 0
Production Deployment Ready     | ❌      | ✅
─────────────────────────────────┴─────────┴────────
```

---

## Next Action

**START HERE:**

1. Read `PHASE_1_COMPLETION_CHECKLIST.md`
2. Pick ONE task from Phase 1
3. Complete it fully
4. Get code review
5. Move to next task

**Do NOT:**
- Skip phases
- Skip testing
- Skip code reviews
- Commit secrets

---

**Prepared:** April 27, 2026  
**Next Review:** After Phase 1 completion  
**Questions?** Review the detailed phase files


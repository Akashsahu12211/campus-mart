# Backend Optimization Roadmap - Campus Mart v2

**Generated:** April 28, 2026  
**Document Purpose:** Specific code fixes and implementation recommendations  
**Priority:** Based on impact to performance, security, and scalability

---

## CRITICAL FIXES (Do Before Production)

### 1. Fix N+1 Query in ItemService

**Current Code (BROKEN):**
```java
// ItemService.java
public List<Item> getAllAvailableItems() {
    List<Item> items = itemRepository.findByStatusOrderByCreatedAtDesc(ItemStatus.AVAILABLE);
    populateSellerRatings(items);  // ← 1 + (N*2) queries for N items!
    return items;
}

private void populateSellerRatings(List<Item> items) {
    items.forEach(this::populateSellerRating);
}

private void populateSellerRating(Item item) {
    Double avgRating = reviewRepository.getAverageRatingBySellerId(item.getSeller().getId());
    Long totalReviews = reviewRepository.countBySellerId(item.getSeller().getId());
    item.getSeller().setAverageRating(avgRating != null ? Math.round(avgRating * 10.0) / 10.0 : 0.0);
    item.getSeller().setTotalReviews(totalReviews != null ? totalReviews : 0L);
}
```

**Problem:** 20 items = 41 queries, 100 items = 201 queries

**Fixed Code:**
```java
// ItemRepository.java - Add new method
@Query("""
    SELECT 
        i,
        COALESCE(AVG(r.rating), 0.0) as avgRating,
        COUNT(r) as totalReviews
    FROM Item i
    LEFT JOIN Review r ON r.seller.id = i.seller.id
    WHERE i.status = :status
    GROUP BY i.id
    ORDER BY i.createdAt DESC
""")
List<Object[]> findAvailableWithSellerRatings(@Param("status") ItemStatus status);

// ItemService.java - Use new method
public List<Item> getAllAvailableItems() {
    List<Object[]> results = itemRepository.findAvailableWithSellerRatings(ItemStatus.AVAILABLE);
    List<Item> items = new ArrayList<>();
    
    for (Object[] row : results) {
        Item item = (Item) row[0];
        Double avgRating = (Double) row[1];
        Long totalReviews = (Long) row[2];
        
        item.getSeller().setAverageRating(Math.round(avgRating * 10.0) / 10.0);
        item.getSeller().setTotalReviews(totalReviews);
        items.add(item);
    }
    
    return items;
}
```

**Result:** 1 query instead of 41! For 100 items: 1 query instead of 201!

**Timeline:** 2-3 hours

---

### 2. Remove Razorpay Test Keys from Code

**Current Code (DANGEROUS):**
```java
// PaymentService.java
@Value("${razorpay.key.id:rzp_test_SfRn4qcORkXcHX}")
private String razorpayKeyId;

@Value("${razorpay.key.secret:WJ1D68TJL2IseUcQjZTIFXnt}")
private String razorpayKeySecret;
```

**And in application.properties:**
```properties
//razorpay.key.id=${RAZORPAY_KEY_ID:rzp_test_SfRn4qcORkXcHX}
#razorpay.key.secret=${RAZORPAY_KEY_SECRET:WJ1D68TJL2IseUcQjZTIFXnt}
```

**Fixed Code:**
```java
// PaymentService.java
@Value("${razorpay.key.id}")
private String razorpayKeyId;

@Value("${razorpay.key.secret}")
private String razorpayKeySecret;

@PostConstruct
public void validateConfiguration() {
    if (razorpayKeyId == null || razorpayKeyId.trim().isEmpty()) {
        throw new IllegalStateException(
            "FATAL: RAZORPAY_KEY_ID environment variable not set. " +
            "Please set it before starting the application."
        );
    }
    if (razorpayKeySecret == null || razorpayKeySecret.trim().isEmpty()) {
        throw new IllegalStateException(
            "FATAL: RAZORPAY_KEY_SECRET environment variable not set. " +
            "Please set it before starting the application."
        );
    }
    if (razorpayKeyId.startsWith("rzp_test_")) {
        logger.warn("WARNING: Using Razorpay TEST keys! Only for development.");
    }
}
```

**And in application.properties:**
```properties
# Remove all comments and fallback values:
razorpay.key.id=${RAZORPAY_KEY_ID}
razorpay.key.secret=${RAZORPAY_KEY_SECRET}
```

**Clean Git History:**
```bash
# Remove test keys from git history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch PaymentService.java application.properties" \
  --prune-empty --tag-name-filter cat -- --all

# Or use BFG (simpler):
bfg --replace-text <(echo 'rzp_test_SfRn4qcORkXcHX') --replace-text <(echo 'WJ1D68TJL2IseUcQjZTIFXnt')
```

**Timeline:** 1 hour

---

### 3. Fix JWT_SECRET to Fail Fast

**Current Code (DANGEROUS):**
```java
// JwtUtil.java
@Value("${jwt.secret}")
private String secret;

@PostConstruct
void init() {
    this.key = Keys.hmacShaKeyFor(secret.getBytes());  // ← NullPointerException!
}
```

**Fixed Code:**
```java
@Value("${jwt.secret:}")
private String secret;

@PostConstruct
void init() {
    if (secret == null || secret.trim().isEmpty()) {
        String errorMsg = "FATAL CONFIGURATION ERROR: JWT_SECRET environment variable must be set.\n" +
                         "Generate a random secret: openssl rand -base64 32\n" +
                         "Then set: export JWT_SECRET=<generated-value>";
        logger.error(errorMsg);
        throw new IllegalStateException(errorMsg);
    }
    
    if (secret.length() < 32) {
        logger.warn("WARNING: JWT_SECRET is less than 32 bytes, should be at least 256 bits");
    }
    
    try {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    } catch (IllegalArgumentException e) {
        throw new IllegalStateException("JWT_SECRET must be valid base64 or at least 32 bytes", e);
    }
}
```

**Timeline:** 30 minutes

---

### 4. Replace System.err with SLF4J Logging

**Current Code (UNPROFESSIONAL):**
```java
// GlobalExceptionHandler.java
@ExceptionHandler(RuntimeException.class)
public ResponseEntity<?> handleRuntimeException(RuntimeException e) {
    Map<String, Object> error = new HashMap<>();
    error.put("error", e.getMessage());
    error.put("timestamp", LocalDateTime.now());
    error.put("status", HttpStatus.BAD_REQUEST.value());
    
    System.err.println("[RUNTIME_ERROR] " + e.getMessage());  // ← BAD!
    e.printStackTrace();  // ← BAD!
    
    return ResponseEntity.badRequest().body(error);
}
```

**Fixed Code:**
```java
// Add to pom.xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-logging</artifactId>
</dependency>

// GlobalExceptionHandler.java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    
    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<?> handleRuntimeException(RuntimeException e) {
        Map<String, Object> error = new HashMap<>();
        error.put("error", e.getMessage());
        error.put("timestamp", LocalDateTime.now());
        error.put("status", HttpStatus.BAD_REQUEST.value());
        
        logger.error("Runtime exception occurred", e);  // ← GOOD!
        
        return ResponseEntity.badRequest().body(error);
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<?> handleAuthenticationException(AuthenticationException e) {
        logger.warn("Authentication failed: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(Map.of("error", "Authentication failed"));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<?> handleAccessDeniedException(AccessDeniedException e) {
        logger.warn("Access denied: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(Map.of("error", "Access denied"));
    }
}
```

**And in other services:**
```java
// ChatService.java - BEFORE (BAD)
System.out.println("💬 ChatService.sendMessage: " + senderId + " -> " + receiverId);
System.err.println("❌ Sender not found: " + senderId);

// ChatService.java - AFTER (GOOD)
private static final Logger logger = LoggerFactory.getLogger(ChatService.class);

logger.info("Message sent from {} to {}", senderId, receiverId);
logger.error("Sender not found: {}", senderId);
```

**Timeline:** 2 hours

---

### 5. Fix AdminService Dashboard N+1 Queries

**Current Code (BROKEN):**
```java
// AdminService.java
public Map<String, Object> getDashboardStats() {
    // Individual count queries - at least 20 queries!
    long totalUsers = studentRepo.count();
    long bannedUsers = studentRepo.countByIsBanned(true);
    long adminCount = studentRepo.countByRole(StudentRole.ADMIN);
    long modCount = studentRepo.countByRole(StudentRole.MODERATOR);
    
    // ... more count queries ...
    
    // Full table scan + in-memory filtering
    java.math.BigDecimal grossMerchandiseValue = safeAmount(() ->
        paymentRepo.findAll().stream()  // ← Load entire payment table!
            .filter(order -> order.getStatus() == PaymentOrder.PaymentStatus.RELEASED ||
                           order.getStatus() == PaymentOrder.PaymentStatus.ESCROW_HOLD ||
                           order.getStatus() == PaymentOrder.PaymentStatus.PAID)
            .map(PaymentOrder::getAmount)
            .filter(Objects::nonNull)
            .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add)
    );
}
```

**Fixed Code:**
```java
// AdminRepository.java - New interface
@Repository
public interface AdminStatsRepository extends JpaRepository<AdminLog, Long> {
    
    @Query("""
        SELECT 
            COUNT(*) as totalUsers,
            SUM(CASE WHEN is_banned = true THEN 1 ELSE 0 END) as bannedUsers,
            SUM(CASE WHEN role = 'ADMIN' THEN 1 ELSE 0 END) as adminCount,
            SUM(CASE WHEN role = 'MODERATOR' THEN 1 ELSE 0 END) as modCount
        FROM students
    """)
    Map<String, Long> getUserStats();
    
    @Query("""
        SELECT 
            COUNT(*) as totalPayments,
            SUM(CASE WHEN status = 'RELEASED' THEN 1 ELSE 0 END) as releasedCount,
            SUM(CASE WHEN status = 'DISPUTED' THEN 1 ELSE 0 END) as disputedCount,
            COALESCE(SUM(CASE WHEN status IN ('RELEASED', 'ESCROW_HOLD', 'PAID') 
                                THEN amount ELSE 0 END), 0) as totalValue
        FROM payment_orders
    """)
    Map<String, Object> getPaymentStats();
}

// AdminService.java - FIXED
@Autowired
private AdminStatsRepository adminStatsRepo;

public Map<String, Object> getDashboardStats() {
    Map<String, Object> stats = new LinkedHashMap<>();
    
    // Single aggregation query instead of 20+
    Map<String, Long> userStats = adminStatsRepo.getUserStats();
    Map<String, Object> paymentStats = adminStatsRepo.getPaymentStats();
    
    stats.put("users", Map.of(
        "total", userStats.get("totalUsers"),
        "banned", userStats.get("bannedUsers"),
        "admins", userStats.get("adminCount"),
        "mods", userStats.get("modCount")
    ));
    
    stats.put("payments", Map.of(
        "total", paymentStats.get("totalPayments"),
        "released", paymentStats.get("releasedCount"),
        "disputed", paymentStats.get("disputedCount"),
        "value", paymentStats.get("totalValue")
    ));
    
    return stats;
}
```

**Result:** 20+ queries → 2 queries!

**Timeline:** 3 hours

---

## HIGH PRIORITY FIXES

### 6. Add Refresh Token Mechanism

**Current Problem:** Users must re-login after 7 days

**Solution:**

```java
// New entity: RefreshToken.java
@Entity
@Table(name = "refresh_tokens")
@Data
@NoArgsConstructor
public class RefreshToken {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "student_id")
    private Student student;
    
    @Column(nullable = false, unique = true)
    private String token;
    
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
    
    @Column(name = "revoked")
    private Boolean revoked = false;
}

// RefreshTokenRepository.java
@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {
    Optional<RefreshToken> findByToken(String token);
    Optional<RefreshToken> findByStudentId(Long studentId);
    void deleteByStudentIdAndRevokedTrue(Long studentId);
}

// JwtUtil.java - Updated
@Component
public class JwtUtil {
    
    @Value("${jwt.access-token.expiry.ms:3600000}")  // 1 hour
    private long accessTokenExpiryMs;
    
    @Value("${jwt.refresh-token.expiry.ms:2592000000}")  // 30 days
    private long refreshTokenExpiryMs;
    
    private Key key;
    
    @PostConstruct
    void init() {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
    }
    
    // Generate access token (short-lived)
    public String generateAccessToken(Long userId, String email) {
        return Jwts.builder()
            .setSubject(String.valueOf(userId))
            .claim("email", email)
            .claim("type", "access")
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + accessTokenExpiryMs))
            .signWith(key, SignatureAlgorithm.HS256)
            .compact();
    }
    
    // Generate refresh token (long-lived)
    public String generateRefreshToken(Long userId, String email) {
        return Jwts.builder()
            .setSubject(String.valueOf(userId))
            .claim("email", email)
            .claim("type", "refresh")
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + refreshTokenExpiryMs))
            .signWith(key, SignatureAlgorithm.HS256)
            .compact();
    }
    
    public String getTokenType(String token) {
        Claims claims = Jwts.parserBuilder()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .getBody();
        return claims.get("type", String.class);
    }
}

// AuthController.java - Updated login endpoint
@PostMapping("/login")
public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
    String email = body.get("email").toLowerCase().trim();
    String password = body.get("password").trim();
    
    // ... existing validation ...
    
    Student student = studentRepo.findByEmail(email)
        .orElseThrow(() -> new RuntimeException("Email not found"));
    
    // ... existing password check ...
    
    // Generate both tokens
    String accessToken = jwtUtil.generateAccessToken(student.getId(), student.getEmail());
    String refreshToken = jwtUtil.generateRefreshToken(student.getId(), student.getEmail());
    
    // Save refresh token to DB
    RefreshToken rt = new RefreshToken();
    rt.setStudent(student);
    rt.setToken(refreshToken);
    rt.setExpiresAt(LocalDateTime.now().plusDays(30));
    refreshTokenRepository.save(rt);
    
    return ResponseEntity.ok(Map.of(
        "accessToken", accessToken,
        "refreshToken", refreshToken,
        "expiresIn", 3600,  // seconds
        "tokenType", "Bearer"
    ));
}

// New endpoint: POST /api/auth/refresh
@PostMapping("/refresh")
public ResponseEntity<?> refreshAccessToken(@RequestBody Map<String, String> body) {
    String refreshToken = body.get("refreshToken");
    
    if (!jwtUtil.validateToken(refreshToken)) {
        return ResponseEntity.status(401).body(Map.of("error", "Invalid or expired refresh token"));
    }
    
    if (!"refresh".equals(jwtUtil.getTokenType(refreshToken))) {
        return ResponseEntity.status(401).body(Map.of("error", "Token is not a refresh token"));
    }
    
    Long userId = jwtUtil.getUserIdFromToken(refreshToken);
    RefreshToken rt = refreshTokenRepository.findByToken(refreshToken)
        .orElseThrow(() -> new RuntimeException("Refresh token not found"));
    
    if (Boolean.TRUE.equals(rt.getRevoked())) {
        return ResponseEntity.status(401).body(Map.of("error", "Refresh token has been revoked"));
    }
    
    if (rt.getExpiresAt().isBefore(LocalDateTime.now())) {
        return ResponseEntity.status(401).body(Map.of("error", "Refresh token expired"));
    }
    
    Student student = studentRepo.findById(userId).orElseThrow();
    String newAccessToken = jwtUtil.generateAccessToken(student.getId(), student.getEmail());
    
    return ResponseEntity.ok(Map.of(
        "accessToken", newAccessToken,
        "expiresIn", 3600
    ));
}

// Logout endpoint: POST /api/auth/logout
@PostMapping("/logout")
public ResponseEntity<?> logout(@RequestHeader("Authorization") String authHeader) {
    Long userId = SecurityUtils.getCurrentUserId();
    
    RefreshToken rt = refreshTokenRepository.findByStudentId(userId).orElse(null);
    if (rt != null) {
        rt.setRevoked(true);
        refreshTokenRepository.save(rt);
    }
    
    return ResponseEntity.ok(Map.of("message", "Logged out successfully"));
}
```

**Update application.properties:**
```properties
# Access token: 1 hour
jwt.access-token.expiry.ms=3600000

# Refresh token: 30 days
jwt.refresh-token.expiry.ms=2592000000
```

**Update frontend:**
```javascript
// Store both tokens
localStorage.setItem('accessToken', response.accessToken);
localStorage.setItem('refreshToken', response.refreshToken);

// Handle 401 with automatic refresh
axios.interceptors.response.use(
    response => response,
    async error => {
        if (error.response.status === 401) {
            const refreshToken = localStorage.getItem('refreshToken');
            const newAccessToken = await fetch('/api/auth/refresh', {
                method: 'POST',
                body: JSON.stringify({ refreshToken })
            }).then(r => r.json()).then(d => d.accessToken);
            
            localStorage.setItem('accessToken', newAccessToken);
            // Retry original request with new token
        }
        return Promise.reject(error);
    }
);
```

**Timeline:** 4-5 hours

---

### 7. Add Structured Logging Configuration

**Update pom.xml:**
```xml
<!-- Remove default Logback, add JSON logging -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.3</version>
</dependency>
```

**Create logback-spring.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProperty name="LOG_FILE" source="logging.file.name"/>
    
    <!-- Console - Human readable -->
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>
    
    <!-- JSON File - Machine parseable -->
    <appender name="FILE_JSON" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_FILE}</file>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeContext>true</includeContext>
            <includeCallerData>true</includeCallerData>
            <customFields>{"service":"campus-mart","environment":"${ENVIRONMENT:dev}"}</customFields>
        </encoder>
        <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
            <fileNamePattern>${LOG_FILE}.%d{yyyy-MM-dd}.%i.gz</fileNamePattern>
            <maxFileSize>10MB</maxFileSize>
            <maxHistory>30</maxHistory>
            <totalSizeCap>500MB</totalSizeCap>
        </rollingPolicy>
    </appender>
    
    <logger name="com.campusmart" level="DEBUG"/>
    <logger name="org.springframework" level="INFO"/>
    
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE_JSON"/>
    </root>
</configuration>
```

**Update all services to use logging:**
```java
public class ItemService {
    private static final Logger logger = LoggerFactory.getLogger(ItemService.class);
    
    public List<Item> getAllAvailableItems() {
        logger.debug("Fetching all available items");
        List<Item> items = itemRepository.findByStatusOrderByCreatedAtDesc(ItemStatus.AVAILABLE);
        logger.info("Fetched {} available items", items.size());
        return items;
    }
}
```

**Timeline:** 2-3 hours

---

## MEDIUM PRIORITY FIXES

### 8. Input Validation - Add DTOs for All Major Operations

**Current:** Only 5 DTOs defined, many endpoints use Map<String, Object>

**Create ItemCreateRequest.java:**
```java
@Data
public class ItemCreateRequest {
    @NotBlank(message = "Title is required")
    @Size(min = 5, max = 100, message = "Title must be 5-100 characters")
    private String title;
    
    @NotBlank(message = "Description is required")
    @Size(min = 20, max = 2000, message = "Description must be 20-2000 characters")
    private String description;
    
    @NotNull(message = "Price is required")
    @Positive(message = "Price must be positive")
    @DecimalMax(value = "999999.99", message = "Price too high")
    private BigDecimal price;
    
    @NotNull(message = "Category ID is required")
    @Positive(message = "Category ID must be positive")
    private Long categoryId;
    
    @NotNull(message = "Condition is required")
    @Pattern(regexp = "NEW|LIKE_NEW|GOOD|FAIR|POOR", message = "Invalid condition")
    private String condition;
    
    @NotEmpty(message = "At least one image is required")
    @Size(max = 5, message = "Maximum 5 images allowed")
    private List<String> imageUrls;
    
    private boolean negotiable = false;
}

// ItemController.java - Use DTO
@PostMapping
public ResponseEntity<?> createItem(
        @Valid @RequestBody ItemCreateRequest request,
        HttpServletRequest httpRequest) {
    
    Long userId = SecurityUtils.getCurrentUserId();
    Student seller = studentRepo.findById(userId)
        .orElseThrow(() -> new RuntimeException("User not found"));
    
    // Rate limiting
    if (!rateLimiter.allowCreateItem(String.valueOf(userId))) {
        return ResponseEntity.status(429)
            .body(Map.of("error", "Rate limit exceeded for item creation"));
    }
    
    // Create and save item
    Item item = new Item();
    item.setTitle(request.getTitle());
    item.setDescription(request.getDescription());
    item.setPrice(request.getPrice());
    item.setCondition(Item.ItemCondition.valueOf(request.getCondition()));
    item.setImageUrls(request.getImageUrls());
    item.setNegotiable(request.isNegotiable());
    item.setSeller(seller);
    
    Item saved = itemService.addItem(item);
    logger.info("Item created by user {}: {}", userId, saved.getId());
    
    return ResponseEntity.status(201).body(saved);
}
```

**Create PaymentCreateOrderRequest.java:**
```java
@Data
public class PaymentCreateOrderRequest {
    @NotNull(message = "Item ID is required")
    @Positive(message = "Item ID must be positive")
    private Long itemId;
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    @DecimalMax(value = "1000000.00", message = "Amount exceeds maximum")
    private BigDecimal amount;
    
    @Size(max = 500, message = "Notes cannot exceed 500 characters")
    private String notes;
}
```

**Timeline:** 3 hours

---

### 9. Add FULLTEXT Search Index

**Create migration V3__add_fulltext_indexes.sql:**
```sql
-- For title and description search
ALTER TABLE items 
ADD FULLTEXT INDEX idx_ft_search (title, description);

-- Optional: Separate index for title only (faster for title-only queries)
ALTER TABLE items 
ADD FULLTEXT INDEX idx_ft_title (title);
```

**Update ItemRepository.java:**
```java
@Query(value = """
    SELECT * FROM items 
    WHERE status = :status 
    AND MATCH(title, description) AGAINST(:query IN BOOLEAN MODE)
    ORDER BY created_at DESC
    LIMIT :limit OFFSET :offset
""", nativeQuery = true)
List<Item> searchFulltext(
    @Param("query") String query,
    @Param("status") String status,
    @Param("limit") int limit,
    @Param("offset") int offset
);
```

**Update ItemService.java:**
```java
public List<Item> searchItems(String query) {
    if (query == null || query.length() < 3) {
        return Collections.emptyList();
    }
    
    // Format for BOOLEAN MODE search
    String formattedQuery = "+" + query.replace(" ", "* +") + "*";
    
    List<Item> items = itemRepository.searchFulltext(
        formattedQuery, ItemStatus.AVAILABLE.name(), 20, 0
    );
    populateSellerRatings(items);  // Now fixed with JOIN query
    return items;
}
```

**Timeline:** 1-2 hours

---

### 10. Add Spring Boot Profiles

**Create application-dev.properties:**
```properties
# Dev environment
logging.level.com.campusmart=DEBUG
logging.level.org.springframework.security=DEBUG
logging.level.org.hibernate.SQL=DEBUG

spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

app.frontend.base-url=http://localhost:3000
app.cors.allowed-origins=http://localhost:3000,http://localhost:3001
app.websocket.allowed-origins=http://localhost:3000,http://localhost:3001

# Flyway
spring.flyway.enabled=true
```

**Create application-prod.properties:**
```properties
# Production environment
logging.level.root=INFO
logging.level.com.campusmart=INFO
logging.level.org.springframework=WARN

spring.jpa.show-sql=false

# Must be set via env vars in production!
app.frontend.base-url=${APP_FRONTEND_BASE_URL}
app.cors.allowed-origins=${APP_CORS_ALLOWED_ORIGINS}
app.websocket.allowed-origins=${APP_WEBSOCKET_ALLOWED_ORIGINS}

# Security
spring.security.require-https=true

# Database pool
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=5
```

**Create application-test.properties:**
```properties
# Test environment
spring.datasource.url=jdbc:h2:mem:testdb
spring.datasource.driverClassName=org.h2.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.show-sql=true

logging.level.com.campusmart=DEBUG

# Disable external integrations
notifications.push.enabled=false
notifications.email.enabled=false
```

**Update pom.xml for H2:**
```xml
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>test</scope>
</dependency>
```

**Timeline:** 1 hour

---

## Summary Table

| Fix | Priority | Effort | Impact | Timeline |
|:---|:--------:|:------:|:------:|:--------:|
| Fix N+1 in ItemService | 🔴 | Medium | Very High | 2-3h |
| Remove Razorpay test keys | 🔴 | Low | Critical | 1h |
| JWT_SECRET validation | 🔴 | Low | Critical | 30m |
| Replace System.err with SLF4J | 🔴 | Medium | High | 2h |
| Fix AdminService queries | 🔴 | Medium | High | 3h |
| Refresh token mechanism | 🟠 | High | Very High | 4-5h |
| Structured logging | 🟠 | Medium | High | 2-3h |
| Input validation DTOs | 🟠 | Medium | High | 3h |
| FULLTEXT search index | 🟡 | Low | Medium | 1-2h |
| Spring profiles | 🟡 | Low | Medium | 1h |

**Total Critical Fixes:** ~11 hours  
**Total High Priority:** ~10 hours  
**Total Medium Priority:** ~4 hours

---

## Deployment Checklist

Before going to production:

- [ ] All critical fixes implemented
- [ ] Remove all System.err/System.out logging
- [ ] Set all required environment variables (use secrets manager)
- [ ] Configure email/SMS credentials (Twilio, Gmail)
- [ ] Set Firebase service account path
- [ ] Generate random JWT_SECRET (don't reuse old keys)
- [ ] Set Razorpay live keys (not test keys!)
- [ ] Test refresh token flow end-to-end
- [ ] Load test N+1 fixes (verify query reduction)
- [ ] Configure CDN for static assets
- [ ] Set up monitoring/alerting (New Relic, DataDog, etc.)
- [ ] Enable HTTPS/TLS
- [ ] Set up database backups
- [ ] Configure log aggregation (ELK, Splunk, etc.)
- [ ] Review security headers (CSP, HSTS, X-Frame-Options)


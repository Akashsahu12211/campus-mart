package com.campusmart.security;

import com.campusmart.config.FirebaseConfig;
import com.campusmart.config.JwtUtil;
import com.campusmart.config.RefreshTokenUtil;
import com.campusmart.config.SecureTransportEnforcementFilter;
import com.campusmart.config.SecurityConfig;
import com.campusmart.controller.AdminController;
import com.campusmart.controller.ItemController;
import com.campusmart.controller.PublicHealthController;
import com.campusmart.controller.StudentController;
import com.campusmart.model.Student;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.ReviewRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.TransactionRepository;
import com.campusmart.repository.WishlistRepository;
import com.campusmart.service.AdminService;
import com.campusmart.service.ItemService;
import com.campusmart.service.LegacyItemImageMigrationService;
import com.campusmart.service.NotificationEventService;
import com.campusmart.service.NotificationTokenService;
import com.campusmart.service.SiteAssetService;
import com.campusmart.service.StudentService;
import com.campusmart.util.OwnershipValidator;
import com.campusmart.util.RateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = {
    ItemController.class,
    StudentController.class,
    AdminController.class,
    PublicHealthController.class
})
@Import({SecurityConfig.class, JwtUtil.class, SecureTransportEnforcementFilter.class})
@TestPropertySource(properties = {
    "jwt.secret=01234567890123456789012345678901",
    "jwt.expiry.ms=3600000",
    "app.require-secure-transport=false"
})
@DisplayName("Endpoint Security Tests")
class EndpointSecurityTests {

    private static final Long USER_ID = 1L;
    private static final Long ADMIN_ID = 2L;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @MockBean
    private StudentRepository studentRepository;

    @MockBean
    private StudentService studentService;

    @MockBean
    private ItemRepository itemRepository;

    @MockBean
    private WishlistRepository wishlistRepository;

    @MockBean
    private TransactionRepository transactionRepository;

    @MockBean
    private ReviewRepository reviewRepository;

    @MockBean
    private ItemService itemService;

    @MockBean
    private OwnershipValidator ownershipValidator;

    @MockBean
    private NotificationEventService notificationEventService;

    @MockBean
    private RateLimiter rateLimiter;

    @MockBean
    private AdminService adminService;

    @MockBean
    private SiteAssetService siteAssetService;

    @MockBean
    private NotificationTokenService notificationTokenService;

    @MockBean
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private RefreshTokenUtil refreshTokenUtil;

    @MockBean
    private FirebaseConfig firebaseConfig;

    @MockBean
    private LegacyItemImageMigrationService legacyItemImageMigrationService;

    @BeforeEach
    void setUp() {
        Student student = student(USER_ID, "user@example.com", StudentRole.STUDENT);
        Student admin = student(ADMIN_ID, "admin@example.com", StudentRole.ADMIN);

        when(studentRepository.findById(USER_ID)).thenReturn(Optional.of(student));
        when(studentRepository.findById(ADMIN_ID)).thenReturn(Optional.of(admin));
        when(studentService.getStudentById(USER_ID)).thenReturn(Optional.of(student));
        when(itemService.getAllAvailableItems()).thenReturn(List.of());
        when(jdbcTemplate.queryForObject("SELECT 1", Integer.class)).thenReturn(1);
        when(refreshTokenUtil.getRefreshExpiryMs()).thenReturn(2_592_000_000L);
        when(adminService.getDashboardStats()).thenReturn(Map.of("users", Map.of("total", 1)));
        when(rateLimiter.allowCreateItem(anyString())).thenReturn(true);
        when(firebaseConfig.isPushEnabled()).thenReturn(false);
        when(firebaseConfig.isMessagingReady()).thenReturn(false);
        when(firebaseConfig.getCredentialSource()).thenReturn("disabled");
        when(firebaseConfig.getLastError()).thenReturn("");
        when(legacyItemImageMigrationService.getInlineImageStats()).thenReturn(Map.of(
            "itemsWithInlineImages", 0,
            "inlineImageCount", 0
        ));
    }

    @Test
    @DisplayName("Public health endpoint is accessible without auth")
    void testPublicHealthEndpoint() throws Exception {
        mockMvc.perform(get("/api/public/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    @DisplayName("Public items endpoint is accessible without auth")
    void testPublicItemsEndpoint() throws Exception {
        mockMvc.perform(get("/api/items"))
            .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Public readiness endpoint is accessible without auth")
    void testReadinessEndpoint() throws Exception {
        mockMvc.perform(get("/api/public/ready"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.checks.database").value("UP"));
    }

    @Test
    @DisplayName("Protected student endpoint requires valid JWT token")
    void testProtectedStudentEndpointWithoutToken() throws Exception {
        mockMvc.perform(get("/api/students/{id}", USER_ID))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Protected student endpoint accepts valid JWT token")
    void testProtectedStudentEndpointWithValidToken() throws Exception {
        mockMvc.perform(get("/api/students/{id}", USER_ID)
                .header("Authorization", bearerToken(USER_ID, "user@example.com")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(USER_ID));
    }

    @Test
    @DisplayName("Invalid JWT token is rejected")
    void testProtectedEndpointWithInvalidToken() throws Exception {
        mockMvc.perform(get("/api/students/{id}", USER_ID)
                .header("Authorization", "Bearer invalid.token.here"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Admin endpoints require ADMIN role")
    void testAdminEndpointProtection() throws Exception {
        mockMvc.perform(get("/api/admin/stats")
                .header("Authorization", bearerToken(USER_ID, "user@example.com")))
            .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Admin endpoints allow admins")
    void testAdminEndpointWithAdminToken() throws Exception {
        mockMvc.perform(get("/api/admin/stats")
                .header("Authorization", bearerToken(ADMIN_ID, "admin@example.com")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.users.total").value(1));
    }

    private Student student(Long id, String email, StudentRole role) {
        Student student = new Student();
        student.setId(id);
        student.setName("User " + id);
        student.setEmail(email);
        student.setRole(role);
        student.setIsActive(true);
        student.setIsBanned(false);
        student.setAuthSessionVersion(0);
        student.setEmailVerified(true);
        student.setPhoneVerified(true);
        return student;
    }

    private String bearerToken(Long userId, String email) {
        return "Bearer " + jwtUtil.generateToken(userId, email, 0);
    }
}

package com.campusmart.config;

import com.campusmart.controller.AdminController;
import com.campusmart.controller.AuthController;
import com.campusmart.controller.ItemController;
import com.campusmart.controller.OfferController;
import com.campusmart.controller.ReportController;
import com.campusmart.controller.ReviewController;
import com.campusmart.controller.StudentController;
import com.campusmart.controller.TransactionController;
import com.campusmart.model.Item;
import com.campusmart.model.Offer;
import com.campusmart.model.RegistrationSession;
import com.campusmart.model.Report;
import com.campusmart.model.Review;
import com.campusmart.model.Student;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.model.Transaction;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.PaymentOrderRepository;
import com.campusmart.repository.OfferRepository;
import com.campusmart.repository.RegistrationSessionRepository;
import com.campusmart.repository.ReportRepository;
import com.campusmart.repository.ReviewRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.TransactionRepository;
import com.campusmart.repository.WishlistRepository;
import com.campusmart.service.AdminService;
import com.campusmart.service.EmailService;
import com.campusmart.service.ItemService;
import com.campusmart.service.NotificationEventService;
import com.campusmart.service.NotificationTokenService;
import com.campusmart.service.OtpService;
import com.campusmart.service.SecurityAuditService;
import com.campusmart.service.SiteAssetService;
import com.campusmart.service.StudentService;
import com.campusmart.util.RateLimiter;
import com.campusmart.util.OwnershipValidator;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = {
    AuthController.class,
    StudentController.class,
    AdminController.class,
    ItemController.class,
    OfferController.class,
    ReportController.class,
    ReviewController.class,
    TransactionController.class
})
@Import({SecurityConfig.class, JwtUtil.class, RefreshTokenUtil.class, SecureTransportEnforcementFilter.class})
@TestPropertySource(properties = {
    "jwt.secret=01234567890123456789012345678901",
    "jwt.expiry.ms=3600000",
    "jwt.refresh.expiry.ms=2592000000",
    "app.require-secure-transport=false"
})
class AuthSecurityVerificationTest {

    private static final Long USER_ID = 101L;
    private static final Long ADMIN_ID = 202L;
    private static final Long OTHER_USER_ID = 303L;
    private static final Long ITEM_ID = 404L;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JwtUtil jwtUtil;

    @MockBean
    private StudentRepository studentRepository;

    @MockBean
    private RegistrationSessionRepository registrationSessionRepository;

    @MockBean
    private OtpService otpService;

    @MockBean
    private EmailService emailService;

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
    private PaymentOrderRepository paymentOrderRepository;

    @MockBean
    private NotificationTokenService notificationTokenService;

    @MockBean
    private OwnershipValidator ownershipValidator;

    @MockBean
    private AdminService adminService;

    @MockBean
    private SiteAssetService siteAssetService;

    @MockBean
    private ItemService itemService;

    @MockBean
    private NotificationEventService notificationEventService;

    @MockBean
    private SecurityAuditService securityAuditService;

    @MockBean
    private OfferRepository offerRepository;

    @MockBean
    private ReportRepository reportRepository;

    @MockBean
    private RateLimiter rateLimiter;

    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @BeforeEach
    void setUp() {
        when(studentRepository.findById(USER_ID)).thenReturn(Optional.of(student(USER_ID, "user@campusmart.test", StudentRole.STUDENT)));
        when(studentRepository.findById(ADMIN_ID)).thenReturn(Optional.of(student(ADMIN_ID, "admin@campusmart.test", StudentRole.ADMIN)));
        when(studentRepository.findById(OTHER_USER_ID)).thenReturn(Optional.of(student(OTHER_USER_ID, "other@campusmart.test", StudentRole.STUDENT)));
        when(studentRepository.save(any(Student.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(rateLimiter.allowLogin(anyString())).thenReturn(true);
        when(rateLimiter.allowOtpGeneration(anyString())).thenReturn(true);
        when(rateLimiter.allowOtpVerification(anyString())).thenReturn(true);
        when(rateLimiter.allowCreateItem(anyString())).thenReturn(true);
        when(rateLimiter.allowCreateOffer(anyString())).thenReturn(true);
        when(rateLimiter.allowPasswordReset(anyString())).thenReturn(true);
    }

    @Test
    void legacyStudentRegisterRouteIsBlocked() throws Exception {
        mockMvc.perform(post("/api/students/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "name": "New User",
                      "email": "new@campusmart.test",
                      "password": "Password123"
                    }
                    """))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error").value("Authentication required"));

        verify(studentService, never()).register(any(Student.class));
    }

    @Test
    void legacyStudentLoginRouteIsBlocked() throws Exception {
        mockMvc.perform(post("/api/students/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "new@campusmart.test",
                      "password": "Password123"
                    }
                    """))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error").value("Authentication required"));
    }

    @Test
    void phaseTwoRegisterRouteStillWorksWithoutToken() throws Exception {
        when(studentRepository.existsByEmail("phase2@campusmart.test")).thenReturn(false);
        when(studentRepository.existsByPhone("9876543210")).thenReturn(false);
        when(registrationSessionRepository.findByEmail("phase2@campusmart.test")).thenReturn(Optional.empty());
        when(registrationSessionRepository.findByPhone("9876543210")).thenReturn(Optional.empty());
        when(registrationSessionRepository.save(any(RegistrationSession.class))).thenAnswer(invocation -> {
            RegistrationSession session = invocation.getArgument(0);
            session.setId(88L);
            return session;
        });
        when(otpService.sendEmailOtpForSession(any(RegistrationSession.class))).thenReturn("123456");

        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "name": "Phase Two",
                      "email": "phase2@campusmart.test",
                      "password": "Password123",
                      "phone": "9876543210"
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.sessionId").value(88L))
            .andExpect(jsonPath("$.nextStep").value("EMAIL_VERIFICATION"));
    }

    @Test
    void loginStillWorksAndReturnsValidJwt() throws Exception {
        Student student = student(USER_ID, "login@campusmart.test", StudentRole.STUDENT);
        student.setPassword(passwordEncoder.encode("Password123"));
        student.setEmailVerified(true);
        student.setPhoneVerified(true);
        student.setIsActive(true);
        student.setLoginAttempts(0);
        when(studentRepository.findByEmail("login@campusmart.test")).thenReturn(Optional.of(student));

        String response = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "email": "login@campusmart.test",
                      "password": "Password123"
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.token").isString())
            .andExpect(jsonPath("$.refreshToken").isString())
            .andExpect(jsonPath("$.student.id").value(USER_ID))
            .andReturn()
            .getResponse()
            .getContentAsString();

        String token = objectMapper.readTree(response).get("token").asText();
        assertThat(jwtUtil.validateToken(token)).isTrue();
        assertThat(jwtUtil.getUserIdFromToken(token)).isEqualTo(USER_ID);
        assertThat(jwtUtil.getTokenType(token)).isEqualTo("ACCESS");
    }

    @Test
    void protectedAdminApiRejectsMissingTokenWith401() throws Exception {
        mockMvc.perform(get("/api/admin/stats"))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error").value("Authentication required"));
    }

    @Test
    void normalUserCannotAccessAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/admin/stats")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test")))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.error").value("Access denied"));
    }

    @Test
    void adminCanAccessAdminEndpoints() throws Exception {
        when(adminService.getDashboardStats()).thenReturn(Map.of("users", Map.of("total", 1)));

        mockMvc.perform(get("/api/admin/stats")
                .header("Authorization", bearerToken(ADMIN_ID, "admin@campusmart.test")))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.users.total").value(1));
    }

    @Test
    void itemCreateUsesAuthenticatedUserAsSellerOnly() throws Exception {
        Student currentUser = student(USER_ID, "user@campusmart.test", StudentRole.STUDENT);
        when(studentRepository.findById(USER_ID)).thenReturn(Optional.of(currentUser));
        when(itemService.createItem(any(), eq(currentUser))).thenAnswer(invocation -> {
            Item item = new Item();
            item.setId(ITEM_ID);
            item.setTitle("Secure Item");
            item.setPrice(java.math.BigDecimal.valueOf(999));
            item.setSeller(currentUser);
            return item;
        });

        mockMvc.perform(post("/api/items")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "title": "Secure Item",
                      "price": 999,
                      "categoryId": 1,
                      "condition": "GOOD",
                      "seller": { "id": 9999 }
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(ITEM_ID))
            .andExpect(jsonPath("$.seller.id").value(USER_ID));
    }

    @Test
    void reserveItemUsesAuthenticatedUserAsBuyerOnly() throws Exception {
        Item item = new Item();
        item.setId(ITEM_ID);
        item.setStatus(Item.ItemStatus.AVAILABLE);
        item.setSeller(student(OTHER_USER_ID, "seller@campusmart.test", StudentRole.STUDENT));
        when(itemService.getItemById(ITEM_ID)).thenReturn(Optional.of(item));
        when(itemService.addItem(any(Item.class))).thenAnswer(invocation -> invocation.getArgument(0));

        mockMvc.perform(patch("/api/items/{id}/reserve-by-buyer", ITEM_ID)
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "buyerId": 9999
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.item.reservedBy").value(USER_ID));
    }

    @Test
    void userCannotUpdateAnotherUsersItem() throws Exception {
        doThrow(new RuntimeException("Unauthorized: You are not the owner of this item"))
            .when(ownershipValidator).validateItemOwnership(USER_ID, ITEM_ID);

        mockMvc.perform(put("/api/items/{id}", ITEM_ID)
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "title": "Changed",
                      "price": 999,
                      "categoryId": 1,
                      "condition": "GOOD"
                    }
                    """))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error").value("Unauthorized: You are not the owner of this item"));
    }

    @Test
    void userCannotDeleteAnotherUsersItem() throws Exception {
        doThrow(new RuntimeException("Unauthorized: You are not the owner of this item"))
            .when(ownershipValidator).validateItemOwnership(USER_ID, ITEM_ID);

        mockMvc.perform(delete("/api/items/{id}", ITEM_ID)
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test")))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.error").value("Unauthorized: You are not the owner of this item"));
    }

    @Test
    void userCannotMarkAnotherUsersItemSold() throws Exception {
        doThrow(new RuntimeException("Unauthorized: You are not the owner of this item"))
            .when(ownershipValidator).validateItemOwnership(USER_ID, ITEM_ID);

        mockMvc.perform(patch("/api/items/{id}/sold", ITEM_ID)
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test")))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error").value("Unauthorized: You are not the owner of this item"));
    }

    @Test
    void offerCreationIgnoresSpoofedBuyerId() throws Exception {
        Item item = new Item();
        item.setId(ITEM_ID);
        item.setSeller(student(OTHER_USER_ID, "seller@campusmart.test", StudentRole.STUDENT));
        when(itemRepository.findById(ITEM_ID)).thenReturn(Optional.of(item));
        when(offerRepository.save(any(Offer.class))).thenAnswer(invocation -> {
            Offer offer = invocation.getArgument(0);
            offer.setId(77L);
            return offer;
        });

        mockMvc.perform(post("/api/offers")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "itemId": 404,
                      "buyerId": 9999,
                      "offeredPrice": 650,
                      "note": "Best price"
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.buyer.id").value(USER_ID));
    }

    @Test
    void reportCreationIgnoresSpoofedReporterId() throws Exception {
        Item reportedItem = new Item();
        reportedItem.setId(ITEM_ID);
        reportedItem.setSeller(student(OTHER_USER_ID, "seller@campusmart.test", StudentRole.STUDENT));
        when(itemRepository.findById(ITEM_ID)).thenReturn(Optional.of(reportedItem));
        when(reportRepository.existsByReporterIdAndItemId(USER_ID, ITEM_ID)).thenReturn(false);
        when(reportRepository.save(any(Report.class))).thenAnswer(invocation -> {
            Report report = invocation.getArgument(0);
            report.setId(91L);
            report.setStatus(Report.ReportStatus.PENDING);
            return report;
        });
        when(reportRepository.countByItemIdAndStatus(ITEM_ID, Report.ReportStatus.PENDING)).thenReturn(1L);

        mockMvc.perform(post("/api/reports")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "reporterId": 9999,
                      "itemId": 404,
                      "reason": "SPAM",
                      "description": "Looks fake"
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.report.reporter.id").value(USER_ID));
    }

    @Test
    void reviewCreationIgnoresSpoofedReviewerId() throws Exception {
        when(reviewRepository.existsByReviewerIdAndItemId(USER_ID, ITEM_ID)).thenReturn(false);
        when(paymentOrderRepository.existsByBuyerIdAndSellerIdAndItemIdAndStatus(
            USER_ID,
            OTHER_USER_ID,
            ITEM_ID,
            com.campusmart.model.PaymentOrder.PaymentStatus.RELEASED
        )).thenReturn(true);
        when(reviewRepository.save(any(Review.class))).thenAnswer(invocation -> {
            Review review = invocation.getArgument(0);
            review.setId(66L);
            return review;
        });

        mockMvc.perform(post("/api/reviews")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "reviewerId": 9999,
                      "sellerId": 303,
                      "itemId": 404,
                      "rating": 5,
                      "comment": "Great seller"
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.reviewer.id").value(USER_ID));
    }

    @Test
    void transactionCreationUsesAuthenticatedSellerOnly() throws Exception {
        Item item = new Item();
        item.setId(ITEM_ID);
        item.setPrice(java.math.BigDecimal.valueOf(450));
        item.setSeller(student(USER_ID, "user@campusmart.test", StudentRole.STUDENT));
        item.setStatus(Item.ItemStatus.AVAILABLE);
        when(itemRepository.findById(ITEM_ID)).thenReturn(Optional.of(item));
        when(itemRepository.save(any(Item.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(transactionRepository.save(any(Transaction.class))).thenAnswer(invocation -> {
            Transaction tx = invocation.getArgument(0);
            tx.setId(1234L);
            return tx;
        });

        mockMvc.perform(post("/api/transactions")
                .header("Authorization", bearerToken(USER_ID, "user@campusmart.test"))
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {
                      "buyerId": 303,
                      "sellerId": 9999,
                      "itemId": 404
                    }
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.seller.id").value(USER_ID))
            .andExpect(jsonPath("$.buyer.id").value(OTHER_USER_ID));
    }

    private Student student(Long id, String email, StudentRole role) {
        Student student = new Student();
        student.setId(id);
        student.setName("User " + id);
        student.setEmail(email);
        student.setPassword(passwordEncoder.encode("Password123"));
        student.setRole(role);
        student.setEmailVerified(true);
        student.setPhoneVerified(true);
        student.setIsActive(true);
        student.setLoginAttempts(0);
        student.setIsBanned(false);
        student.setAuthSessionVersion(0);
        return student;
    }

    private String bearerToken(Long userId, String email) {
        return "Bearer " + jwtUtil.generateToken(userId, email);
    }
}

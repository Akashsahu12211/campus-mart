package com.campusmart.controller;

import com.campusmart.config.JwtUtil;
import com.campusmart.config.RefreshTokenUtil;
import com.campusmart.model.OtpVerification;
import com.campusmart.model.Student;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.model.RegistrationSession;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.RegistrationSessionRepository;
import com.campusmart.service.EmailService;
import com.campusmart.service.OtpService;
import com.campusmart.service.SecurityAuditService;
import com.campusmart.util.RateLimiter;
import com.campusmart.util.ServletUtils;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired private StudentRepository studentRepo;
    @Autowired private RegistrationSessionRepository regSessionRepo;
    @Autowired private OtpService        otpService;
    @Autowired private EmailService      emailService;
    @Autowired private JwtUtil           jwtUtil;
    @Autowired private RefreshTokenUtil  refreshTokenUtil;
    @Autowired private RateLimiter       rateLimiter;
    @Autowired private SecurityAuditService securityAuditService;

    @Value("${app.expose-dev-otp:false}")
    private boolean exposeDevOtp;

    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    // Email format regex
    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$"
    );

    // ══════════════════════════════
    // STEP 1: REGISTER (Save to RegistrationSession, NOT Student)
    // ══════════════════════════════
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> body, HttpServletRequest request) {
        try {
            // ── Rate limiting ──
            String clientIp = ServletUtils.getClientIp(request);
            if (!rateLimiter.allowOtpGeneration(clientIp)) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many registration attempts. Please try again later."
                ));
            }

            String name  = body.getOrDefault("name",  "").trim();
            String email = body.getOrDefault("email", "").trim().toLowerCase();
            String password = body.getOrDefault("password", "").trim();
            String phone = body.getOrDefault("phone", "").trim();

            // ── Validations ──
            if (name.isEmpty())
                return error("Name is required");
            if (!EMAIL_PATTERN.matcher(email).matches())
                return error("Please enter a valid email address");
            if (password.length() < 6)
                return error("Password must be at least 6 characters");
            if (!password.matches(".*[A-Za-z].*") || !password.matches(".*[0-9].*"))
                return error("Password must contain letters and numbers");
            if (phone.isEmpty() || !phone.matches("^[6-9]\\d{9}$"))
                return error("Enter a valid 10-digit Indian mobile number");

            // ── Duplicate check (both Student and RegistrationSession) ──
            if (studentRepo.existsByEmail(email)) {
                return error("This email is already registered. Please login to complete verification or reset password if needed.");
            }
            if (studentRepo.existsByPhone(phone))
                return error("This phone number is already registered");
            
            // Clear any pending registration with this email/phone (cascade delete linked OtpSessions)
            regSessionRepo.findByEmail(email).ifPresent(regSessionRepo::delete);
            regSessionRepo.findByPhone(phone).ifPresent(regSessionRepo::delete);

            // ── Create temporary registration session (NOT Student yet) ──
            RegistrationSession session = new RegistrationSession();
            session.setName(name);
            session.setEmail(email);
            session.setPasswordHash(passwordEncoder.encode(password));
            session.setPhone(phone);
            session.setEmailVerified(false);
            session.setPhoneVerified(false);
            session.setExpiresAt(LocalDateTime.now().plusHours(1));
            regSessionRepo.save(session);

            // ── Send email OTP ──
            otpService.sendEmailOtpForSession(session);

            return ResponseEntity.ok(Map.of(
                    "message",   "Verification details submitted! Check your email for OTP.",
                    "sessionId", session.getId(),
                    "nextStep",  "EMAIL_VERIFICATION",
                    "email",     maskEmail(email)
            ));
        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    // ══════════════════════════════
    // STEP 2A: VERIFY EMAIL OTP
    // ══════════════════════════════
    @PostMapping("/verify-email")
    public ResponseEntity<?> verifyEmail(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        try {
            // ── Rate limiting per email ──
            Long sessionId = Long.valueOf(body.get("sessionId").toString());
            RegistrationSession session = regSessionRepo.findById(sessionId)
                    .orElseThrow(() -> new RuntimeException("Registration session not found or expired"));
            
            if (!rateLimiter.allowOtpVerification(session.getEmail())) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many OTP verification attempts. Please try again later."
                ));
            }

            String otp       = body.get("otp").toString().trim();

            if (session.isExpired())
                return error("Registration expired. Please register again.");

            if (session.getEmailVerified())
                return ResponseEntity.ok(Map.of("message", "Email already verified", "nextStep", "PHONE_VERIFICATION"));

            // ── Verify OTP ──
            otpService.verifyOtpForSession(session, otp, OtpVerification.OtpType.EMAIL);

            session.setEmailVerified(true);
            regSessionRepo.save(session);

            // ── Send phone OTP ──
            String phoneOtp = otpService.sendPhoneOtpForSession(session);

            Map<String, Object> resp = new HashMap<>();
            resp.put("message",  "Email verified! OTP sent to your phone.");
            resp.put("nextStep", "PHONE_VERIFICATION");
            resp.put("phone",    maskPhone(session.getPhone()));
            if (exposeDevOtp) {
                resp.put("devPhoneOtp", phoneOtp);
            }
            return ResponseEntity.ok(resp);

        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    // ══════════════════════════════
    // STEP 2B: VERIFY PHONE OTP & CREATE ACCOUNT
    // ══════════════════════════════
    @PostMapping("/verify-phone")
    public ResponseEntity<?> verifyPhone(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        try {
            // ── Rate limiting per email ──
            Long sessionId = Long.valueOf(body.get("sessionId").toString());
            RegistrationSession session = regSessionRepo.findById(sessionId)
                    .orElseThrow(() -> new RuntimeException("Registration session not found or expired"));
            
            if (!rateLimiter.allowOtpVerification(session.getEmail())) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many OTP verification attempts. Please try again later."
                ));
            }

            String otp       = body.get("otp").toString().trim();

            if (session.isExpired())
                return error("Registration expired. Please register again.");

            if (!session.getEmailVerified())
                return error("Please verify your email first");

            // ── Verify phone OTP ──
            otpService.verifyOtpForSession(session, otp, OtpVerification.OtpType.PHONE);

            session.setPhoneVerified(true);
            regSessionRepo.save(session);

            // ─────────────────────────────────────────
            // NOW SAVE TO STUDENT TABLE (Only after both OTPs verified!)
            // ─────────────────────────────────────────
            Student student = new Student();
            student.setName(session.getName());
            student.setEmail(session.getEmail());
            student.setPassword(session.getPasswordHash());
            student.setPhone(session.getPhone());
            student.setEmailVerified(true);
            student.setPhoneVerified(true);
            student.setIsActive(true);
            student.setLoginAttempts(0);
            student.setAuthProvider(Student.AuthProvider.LOCAL);
            markSuccessfulAuth(student, request);
            studentRepo.save(student);

            // ── Delete temporary session (by ID to avoid detached entity issues) ──
            Long tempSessionId = session.getId();
            regSessionRepo.deleteById(tempSessionId);

            // ── Send welcome email ──
            emailService.sendWelcomeEmail(student.getEmail(), student.getName());

            Map<String, Object> resp = buildAuthResponse(
                student,
                "Account created and activated! Welcome to Campus Mart!"
            );
            resp.put("nextStep", "COMPLETE");
            securityAuditService.record(request, student.getId(), "REGISTER_COMPLETE", true, "Account activated after email and phone verification");
            return ResponseEntity.ok(resp);

        } catch (Exception e) {
            securityAuditService.record(request, null, "REGISTER_COMPLETE", false, e.getMessage());
            return error(e.getMessage());
        }
    }

    // ══════════════════════════════
    // RESEND EMAIL OTP
    // ══════════════════════════════
    @PostMapping("/resend-email-otp")
    public ResponseEntity<?> resendEmailOtp(@RequestBody Map<String, Object> body) {
        try {
            Long sessionId = Long.valueOf(body.get("sessionId").toString());
            RegistrationSession session = regSessionRepo.findById(sessionId)
                    .orElseThrow(() -> new RuntimeException("Session not found"));

            if (session.isExpired())
                return error("Registration expired. Please register again.");

            if (session.getEmailVerified())
                return error("Email is already verified");

            otpService.sendEmailOtpForSession(session);
            return ResponseEntity.ok(Map.of(
                    "message", "New OTP sent to " + maskEmail(session.getEmail())
            ));
        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    // ══════════════════════════════
    // RESEND PHONE OTP
    // ══════════════════════════════
    @PostMapping("/resend-phone-otp")
    public ResponseEntity<?> resendPhoneOtp(@RequestBody Map<String, Object> body) {
        try {
            Long sessionId = Long.valueOf(body.get("sessionId").toString());
            RegistrationSession session = regSessionRepo.findById(sessionId)
                    .orElseThrow(() -> new RuntimeException("Session not found"));

            if (session.isExpired())
                return error("Registration expired. Please register again.");

            if (session.getPhoneVerified())
                return error("Phone is already verified");

            String phoneOtp = otpService.sendPhoneOtpForSession(session);
            Map<String, Object> resp = new HashMap<>();
            resp.put("message",     "New OTP sent to " + maskPhone(session.getPhone()));
            if (exposeDevOtp) {
                resp.put("devPhoneOtp", phoneOtp);
            }
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    // ══════════════════════════════
    // LOGIN
    // ══════════════════════════════
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body, HttpServletRequest request) {
        try {
            // ── Rate limiting ──
            String clientIp = ServletUtils.getClientIp(request);
            if (!rateLimiter.allowLogin(clientIp)) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many login attempts. Please try again later."
                ));
            }

            String email    = body.getOrDefault("email",    "").trim().toLowerCase();
            String password = body.getOrDefault("password", "").trim();

            if (email.isEmpty() || password.isEmpty())
                return error("Email and password are required");

            Student student = studentRepo.findByEmail(email)
                    .orElse(null);

            // Generic message (security best practice)
            if (student == null) {
                securityAuditService.record(request, null, "LOGIN", false, "Unknown email");
                return error("Invalid email or password");
            }

            // Account locked check
            if (student.getLockedUntil() != null &&
                    LocalDateTime.now().isBefore(student.getLockedUntil())) {
                long minutesLeft = java.time.Duration.between(
                        LocalDateTime.now(), student.getLockedUntil()).toMinutes();
                return error("Account locked. Try again after " + (minutesLeft + 1) + " minutes.");
            }

            // Password check
            if (!passwordEncoder.matches(password, student.getPassword())) {
                int attempts = student.getLoginAttempts() + 1;
                student.setLoginAttempts(attempts);

                if (attempts >= 5) {
                    student.setLockedUntil(LocalDateTime.now().plusMinutes(15));
                    student.setLoginAttempts(0);
                    studentRepo.save(student);
                    securityAuditService.record(request, student.getId(), "LOGIN", false, "Account locked after repeated failures");
                    return error("Too many wrong attempts. Account locked for 15 minutes.");
                }
                studentRepo.save(student);
                securityAuditService.record(request, student.getId(), "LOGIN", false, "Incorrect password");
                return error("Invalid email or password. " + (5 - attempts) + " attempts remaining.");
            }

            // Reset attempts on success
            student.setLoginAttempts(0);
            student.setLockedUntil(null);

            if (Boolean.TRUE.equals(student.getIsBanned())) {
                studentRepo.save(student);
                return ResponseEntity.status(403).body(Map.of(
                        "error", student.getBanReason() != null && !student.getBanReason().isBlank()
                                ? "Account suspended: " + student.getBanReason()
                                : "Account suspended. Contact support."
                ));
            }

            boolean privilegedUser = student.getRole() == StudentRole.ADMIN
                    || student.getRole() == StudentRole.MODERATOR;

            // Pre-created admin/moderator accounts should not get stuck behind student OTP flow.
            if (privilegedUser) {
                if (!Boolean.TRUE.equals(student.getEmailVerified())) {
                    student.setEmailVerified(true);
                }
                if (!Boolean.TRUE.equals(student.getPhoneVerified())) {
                    student.setPhoneVerified(true);
                }
                if (!Boolean.TRUE.equals(student.getIsActive())) {
                    student.setIsActive(true);
                }
            }

            // Email verified check
            if (!student.getEmailVerified()) {
                studentRepo.save(student);
                otpService.sendEmailOtp(student);
                return ResponseEntity.status(403).body(Map.of(
                        "error",    "Email not verified. New OTP sent to your email.",
                        "userId",   student.getId(),
                        "nextStep", "EMAIL_VERIFICATION"
                ));
            }

            // Phone verified check
            if (!student.getPhoneVerified()) {
                studentRepo.save(student);
                String phoneOtp = otpService.sendPhoneOtp(student);
                Map<String, Object> r = new HashMap<>();
                r.put("error",       "Phone not verified. OTP sent to your phone.");
                r.put("userId",      student.getId());
                r.put("nextStep",    "PHONE_VERIFICATION");
                if (exposeDevOtp) {
                    r.put("devPhoneOtp", phoneOtp);
                }
                return ResponseEntity.status(403).body(r);
            }

            // Active check
            if (!student.getIsActive()) {
                securityAuditService.record(request, student.getId(), "LOGIN", false, "Inactive account");
                return ResponseEntity.status(403).body(Map.of(
                        "error", "Account is inactive. Contact support."
                ));
            }

            markSuccessfulAuth(student, request);
            studentRepo.save(student);
            securityAuditService.record(request, student.getId(), "LOGIN", true, "Login successful");

            return ResponseEntity.ok(buildAuthResponse(student, "Login successful!"));

        } catch (Exception e) {
            securityAuditService.record(request, null, "LOGIN", false, e.getMessage());
            return error(e.getMessage());
        }
    }

    @PostMapping("/forgot-password/request")
    public ResponseEntity<?> requestForgotPassword(@RequestBody Map<String, String> body) {
        try {
            String email = body.getOrDefault("email", "").trim().toLowerCase();
            if (email.isEmpty()) {
                return error("Email is required");
            }

            if (!rateLimiter.allowPasswordReset(email)) {
                return ResponseEntity.status(429).body(Map.of(
                    "error", "Too many reset requests. Please try again later."
                ));
            }

            Student student = studentRepo.findByEmail(email).orElse(null);
            if (student != null) {
                otpService.sendEmailOtp(student);
            }

            return ResponseEntity.ok(Map.of(
                "message", "If an account exists for this email, a password reset OTP has been sent."
            ));
        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    @PostMapping("/forgot-password/reset")
    public ResponseEntity<?> resetForgotPassword(@RequestBody Map<String, String> body) {
        try {
            String email = body.getOrDefault("email", "").trim().toLowerCase();
            String otp = body.getOrDefault("otp", "").trim();
            String newPassword = body.getOrDefault("newPassword", "").trim();

            if (email.isEmpty() || otp.isEmpty() || newPassword.isEmpty()) {
                return error("Email, OTP and new password are required");
            }

            if (newPassword.length() < 6) {
                return error("Password must be at least 6 characters");
            }

            if (!newPassword.matches(".*[A-Za-z].*") || !newPassword.matches(".*[0-9].*")) {
                return error("Password must contain letters and numbers");
            }

            Student student = studentRepo.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("Account not found"));

            otpService.verifyOtp(student, otp, OtpVerification.OtpType.EMAIL);
            student.setPassword(passwordEncoder.encode(newPassword));
            student.setLoginAttempts(0);
            student.setLockedUntil(null);
            student.setAuthSessionVersion(nextSessionVersion(student));
            refreshTokenUtil.revokeAllTokensForUser(student.getId());
            studentRepo.save(student);

            return ResponseEntity.ok(Map.of(
                "message", "Password reset successful. You can login now."
            ));
        } catch (Exception e) {
            return error(e.getMessage());
        }
    }

    @PostMapping("/social-login")
    public ResponseEntity<?> socialLogin(@RequestBody Map<String, String> body, HttpServletRequest request) {
        try {
            String idToken = body.getOrDefault("idToken", "").trim();
            String provider = body.getOrDefault("provider", "").trim().toUpperCase();

            if (idToken.isEmpty()) {
                return error("Social authentication token is required");
            }

            FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(idToken);
            String email = decodedToken.getEmail();
            String name = decodedToken.getName();
            String picture = decodedToken.getPicture();
            String uid = decodedToken.getUid();

            if (email == null || email.isBlank()) {
                return error("Verified social account did not provide an email");
            }

            Student.AuthProvider authProvider =
                "FACEBOOK".equals(provider) ? Student.AuthProvider.FACEBOOK : Student.AuthProvider.GOOGLE;

            Student student = studentRepo.findByEmail(email.toLowerCase())
                .orElseThrow(() -> new RuntimeException(
                    "This email is not registered yet. Please register first, then use Google or Facebook login."
                ));

            if (Boolean.TRUE.equals(student.getIsBanned())) {
                return ResponseEntity.status(403).body(Map.of(
                    "error", student.getBanReason() != null && !student.getBanReason().isBlank()
                        ? "Account suspended: " + student.getBanReason()
                        : "Account suspended. Contact support."
                ));
            }

            student.setName((name != null && !name.isBlank()) ? name : student.getName());
            if (student.getProfilePic() == null || student.getProfilePic().isBlank()) {
                student.setProfilePic(picture);
            }
            student.setEmailVerified(true);
            student.setIsActive(true);
            student.setAuthProvider(authProvider);
            if (authProvider == Student.AuthProvider.GOOGLE) {
                student.setGoogleId(uid);
            } else {
                student.setFacebookId(uid);
            }
            student.setLoginAttempts(0);
            student.setLockedUntil(null);
            markSuccessfulAuth(student, request);

            Student saved = studentRepo.save(student);
            securityAuditService.record(request, saved.getId(), "SOCIAL_LOGIN", true, "Social login successful via " + authProvider.name());
            return ResponseEntity.ok(buildAuthResponse(saved, "Social login successful!"));
        } catch (Exception e) {
            securityAuditService.record(request, null, "SOCIAL_LOGIN", false, e.getMessage());
            return error("Social login failed: " + e.getMessage());
        }
    }

    // ══════════════════════════════
    // HELPER METHODS
    // ══════════════════════════════
    private ResponseEntity<Map<String, String>> error(String msg) {
        return ResponseEntity.badRequest().body(Map.of("error", msg));
    }

    private Map<String, Object> buildAuthResponse(Student student, String message) {
        int sessionVersion = student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion();
        String accessToken = jwtUtil.generateToken(student.getId(), student.getEmail(), sessionVersion);
        String refreshToken = refreshTokenUtil.generateRefreshToken(student.getId(), student.getEmail(), sessionVersion);

        Map<String, Object> response = new HashMap<>();
        response.put("message", message);
        response.put("token", accessToken);
        response.put("refreshToken", refreshToken);
        response.put("expiresIn", jwtUtil.getExpiryMs() / 1000);
        response.put("refreshExpiresIn", refreshTokenUtil.getRefreshExpiryMs() / 1000);
        response.put("student", sanitizeStudent(student));
        return response;
    }

    private void markSuccessfulAuth(Student student, HttpServletRequest request) {
        student.setLastLoginAt(LocalDateTime.now());
        student.setLastLoginIp(ServletUtils.anonymizeIp(ServletUtils.getClientIp(request)));
        if (student.getAuthSessionVersion() == null) {
            student.setAuthSessionVersion(0);
        }
    }

    private int nextSessionVersion(Student student) {
        int current = student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion();
        return current + 1;
    }

    private String extractRefreshToken(
            Map<String, String> body,
            String refreshHeader,
            String authorizationHeader
    ) {
        if (body != null) {
            String bodyToken = body.get("refreshToken");
            if (bodyToken != null && !bodyToken.isBlank()) {
                return bodyToken.trim();
            }
        }
        if (refreshHeader != null && !refreshHeader.isBlank()) {
            return refreshHeader.trim();
        }
        if (authorizationHeader != null && authorizationHeader.startsWith("Bearer ")) {
            return authorizationHeader.substring(7).trim();
        }
        return null;
    }

    private Long extractAuthenticatedUserId(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            return null;
        }
        try {
            return Long.valueOf(userId.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    // ══════════════════════════════
    // REFRESH TOKEN (Extend session without re-login)
    // ══════════════════════════════
    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(
            @RequestBody(required = false) Map<String, String> body,
            @RequestHeader(value = "X-Refresh-Token", required = false) String refreshHeader,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            HttpServletRequest request) {
        try {
            String refreshToken = extractRefreshToken(body, refreshHeader, authHeader);
            if (refreshToken == null || refreshToken.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "error", "Refresh token is required"
                ));
            }
            if (!refreshTokenUtil.validateRefreshToken(refreshToken)) {
                securityAuditService.record(request, null, "TOKEN_REFRESH", false, "Invalid refresh token");
                return ResponseEntity.status(401).body(Map.of(
                        "error", "Refresh token is invalid or expired. Please login again."
                ));
            }

            Long userId = refreshTokenUtil.getUserIdFromRefreshToken(refreshToken);
            Student student = studentRepo.findById(userId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            if (!Boolean.TRUE.equals(student.getIsActive())) {
                return ResponseEntity.status(403).body(Map.of(
                        "error", "Account is inactive. Contact support."
                ));
            }

            if (Boolean.TRUE.equals(student.getIsBanned())) {
                return ResponseEntity.status(403).body(Map.of(
                        "error", "Account has been banned."
                ));
            }

            Integer refreshSessionVersion = refreshTokenUtil.getSessionVersionFromRefreshToken(refreshToken);
            int currentSessionVersion = student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion();
            if (refreshSessionVersion == null || refreshSessionVersion != currentSessionVersion) {
                refreshTokenUtil.revokeRefreshToken(refreshToken);
                return ResponseEntity.status(401).body(Map.of(
                        "error", "Session expired. Please login again."
                ));
            }

            refreshTokenUtil.revokeRefreshToken(refreshToken);
            securityAuditService.record(request, student.getId(), "TOKEN_REFRESH", true, "Refresh token rotated");
            return ResponseEntity.ok(buildAuthResponse(student, "Token refreshed successfully"));
        } catch (Exception e) {
            securityAuditService.record(request, null, "TOKEN_REFRESH", false, e.getMessage());
            return ResponseEntity.status(401).body(Map.of(
                    "error", "Token refresh failed: " + e.getMessage()
            ));
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(
            @RequestBody(required = false) Map<String, String> body,
            @RequestHeader(value = "X-Refresh-Token", required = false) String refreshHeader,
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            HttpServletRequest request) {
        String refreshToken = extractRefreshToken(body, refreshHeader, null);
        Long userId = extractAuthenticatedUserId(request);

        if (refreshToken != null && refreshTokenUtil.validateRefreshToken(refreshToken)) {
            Long refreshUserId = refreshTokenUtil.getUserIdFromRefreshToken(refreshToken);
            if (userId == null || userId.equals(refreshUserId)) {
                userId = refreshUserId;
                refreshTokenUtil.revokeRefreshToken(refreshToken);
            }
        }

        if (userId != null) {
            securityAuditService.record(request, userId, "LOGOUT", true, "Single-session logout");
        }
        return ResponseEntity.ok(Map.of("message", "Logged out successfully"));
    }

    @PostMapping("/logout-all")
    public ResponseEntity<?> logoutAll(HttpServletRequest request) {
        Long userId = extractAuthenticatedUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                    "error", "Authentication required"
            ));
        }

        Student student = studentRepo.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        student.setAuthSessionVersion(nextSessionVersion(student));
        studentRepo.save(student);
        refreshTokenUtil.revokeAllTokensForUser(userId);
        securityAuditService.record(request, userId, "LOGOUT_ALL", true, "All sessions revoked");
        return ResponseEntity.ok(Map.of(
                "message", "Logged out from all devices"
        ));
    }

    private String maskEmail(String email) {
        int at = email.indexOf('@');
        if (at <= 2) return email;
        return email.charAt(0) + "***" + email.substring(at - 1);
    }

    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 4) return phone;
        return "XXXXXX" + phone.substring(phone.length() - 4);
    }

    private Map<String, Object> sanitizeStudent(Student s) {
        Map<String, Object> m = new HashMap<>();
        m.put("id",            s.getId());
        m.put("name",          s.getName());
        m.put("email",         s.getEmail());
        m.put("phone",         s.getPhone());
        m.put("branch",        s.getBranch());
        m.put("hostel",        s.getHostel());
        m.put("collegeId",     s.getCollegeId());
        m.put("institution",   s.getInstitution());
        m.put("institutionType", s.getInstitutionType());
        m.put("institutionName", s.getInstitutionName());
        m.put("campusName",    s.getCampusName());
        m.put("courseName",    s.getCourseName());
        m.put("classLevel",    s.getClassLevel());
        m.put("city",          s.getCity());
        m.put("stateName",     s.getStateName());
        m.put("countryName",   s.getCountryName());
        m.put("profilePic",    s.getProfilePic());
        m.put("bio",           s.getBio());
        m.put("emailVerified", s.getEmailVerified());
        m.put("phoneVerified", s.getPhoneVerified());
        m.put("isActive",      s.getIsActive());
        m.put("role",          s.getRole());
        m.put("isBanned",      s.getIsBanned());
        m.put("banReason",     s.getBanReason());
        m.put("pushNotificationsEnabled", s.getPushNotificationsEnabled());
        m.put("emailNotificationsEnabled", s.getEmailNotificationsEnabled());
        m.put("showPhoneOnListings", s.getShowPhoneOnListings());
        m.put("allowDirectChat", s.getAllowDirectChat());
        m.put("privacyMode", s.getPrivacyMode());
        m.put("preferredLanguage", s.getPreferredLanguage());
        m.put("locationLabel", s.getLocationLabel());
        m.put("latitude", s.getLatitude());
        m.put("longitude", s.getLongitude());
        m.put("authProvider", s.getAuthProvider());
        m.put("contactAccessTier", s.getContactAccessTier());
        m.put("contactAccessExpiresAt", s.getContactAccessExpiresAt());
        m.put("activeSubscriptionCode", s.getActiveSubscriptionCode());
        m.put("subscriptionActivatedAt", s.getSubscriptionActivatedAt());
        m.put("availableBoostCredits", s.getAvailableBoostCredits());
        m.put("usedBoostCredits", s.getUsedBoostCredits());
        m.put("currentCommissionPercent", s.getCurrentCommissionPercent());
        m.put("moderationStrikeCount", s.getModerationStrikeCount());
        m.put("maskedPhone", s.getMaskedPhone());
        m.put("phoneVisibleToViewer", Boolean.TRUE);
        m.put("contactRevealReason", "OWNER");
        m.put("identityVerified",
            Boolean.TRUE.equals(s.getEmailVerified())
                && Boolean.TRUE.equals(s.getPhoneVerified())
                && Boolean.TRUE.equals(s.getIsActive())
                && !Boolean.TRUE.equals(s.getIsBanned()));
        return m;
    }
}

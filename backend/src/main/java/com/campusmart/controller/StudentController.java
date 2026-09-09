package com.campusmart.controller;

import com.campusmart.config.RefreshTokenUtil;
import com.campusmart.dto.NotificationTokenRequest;
import com.campusmart.model.Item;
import com.campusmart.model.Student;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.ReviewRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.TransactionRepository;
import com.campusmart.repository.WishlistRepository;
import com.campusmart.service.NotificationTokenService;
import com.campusmart.service.StudentService;
import com.campusmart.util.OwnershipValidator;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/students")
public class StudentController {

    @Autowired
    private StudentService studentService;

    @Autowired
    private RefreshTokenUtil refreshTokenUtil;

    @Autowired
    private ItemRepository itemRepository;

    @Autowired
    private WishlistRepository wishlistRepo;

    @Autowired
    private TransactionRepository txRepo;

    @Autowired
    private ReviewRepository reviewRepo;

    @Autowired
    private StudentRepository studentRepo;

    @Autowired
    private OwnershipValidator ownershipValidator;

    @Autowired
    private NotificationTokenService notificationTokenService;

    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Student student) {
        return ResponseEntity.status(HttpStatus.GONE).body(Map.of(
            "error", "Legacy registration endpoint has been retired. Use /api/auth/register."
        ));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> credentials) {
        return ResponseEntity.status(HttpStatus.GONE).body(Map.of(
            "error", "Legacy login endpoint has been retired. Use /api/auth/login."
        ));
    }

    @GetMapping
    public ResponseEntity<List<Student>> getAllStudents(HttpServletRequest request) {
        Student viewer = resolveViewer(request);
        List<Student> students = studentService.getAllStudents().stream()
            .peek(student -> studentService.prepareStudentForViewer(student, viewer))
            .collect(Collectors.toList());
        return ResponseEntity.ok(students);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getStudentById(@PathVariable Long id, HttpServletRequest request) {
        Student viewer = resolveViewer(request);
        return studentService.getStudentById(id)
                .<ResponseEntity<?>>map(student -> {
                    studentService.prepareStudentForViewer(student, viewer);
                    return ResponseEntity.ok(student);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateStudent(@PathVariable Long id, @RequestBody Student student, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            return ResponseEntity.ok(studentService.updateStudent(id, student));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/{id}/change-password")
    public ResponseEntity<?> changePassword(
            @PathVariable Long id,
            @RequestBody Map<String, String> body,
            HttpServletRequest request) {

        String currentPw = body.get("currentPassword");
        String newPw = body.get("newPassword");

        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            if (currentPw == null || currentPw.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Current password is required"));
            }

            if (newPw == null || newPw.trim().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "New password is required"));
            }

            if (newPw.length() < 6) {
                return ResponseEntity.badRequest().body(Map.of("error", "New password must be at least 6 characters"));
            }

            Student student = studentRepo.findById(id)
                    .orElseThrow(() -> new RuntimeException("Student not found"));

            if (!passwordEncoder.matches(currentPw, student.getPassword())) {
                return ResponseEntity.badRequest().body(Map.of("error", "Current password is incorrect"));
            }

            student.setPassword(passwordEncoder.encode(newPw));
            student.setAuthSessionVersion((student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion()) + 1);
            refreshTokenUtil.revokeAllTokensForUser(student.getId());
            studentRepo.save(student);

            return ResponseEntity.ok(Map.of("message", "Password updated successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{id}/stats")
    public ResponseEntity<Map<String, Object>> getStudentStats(@PathVariable Long id) {
        long totalListings = itemRepository.countBySellerId(id);
        long soldItems = itemRepository.countBySellerIdAndStatus(id, Item.ItemStatus.SOLD);
        long totalViews = itemRepository.sumViewCountBySellerId(id);
        long wishlistCount = wishlistRepo.countByStudentId(id);

        Double avgRating = reviewRepo.getAverageRatingBySellerId(id);
        long totalReviews = reviewRepo.countBySellerId(id);

        long boughtCount = 0;
        try {
            boughtCount = txRepo.findByBuyerIdOrderByCreatedAtDesc(id).size();
        } catch (Exception ignored) {
        }

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalListings", totalListings);
        stats.put("soldItems", soldItems);
        stats.put("totalViews", totalViews == 0 ? 0 : totalViews);
        stats.put("wishlistCount", wishlistCount);
        stats.put("avgRating", avgRating == null ? 0.0 : Math.round(avgRating * 10.0) / 10.0);
        stats.put("totalReviews", totalReviews);
        stats.put("boughtCount", boughtCount);

        return ResponseEntity.ok(stats);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteStudent(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            studentService.deleteStudent(id);
            return ResponseEntity.ok(Map.of("message", "Student deleted successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.status(403).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{id}/delete-account")
    public ResponseEntity<?> deleteAccount(
            @PathVariable Long id,
            @RequestBody Map<String, String> body,
            HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            String password = body.getOrDefault("password", "").trim();
            if (password.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Password is required"));
            }

            Student student = studentRepo.findById(id)
                    .orElseThrow(() -> new RuntimeException("Student not found"));

            if (!passwordEncoder.matches(password, student.getPassword())) {
                return ResponseEntity.badRequest().body(Map.of("error", "Password is incorrect"));
            }

            studentService.deleteStudent(id);
            return ResponseEntity.ok(Map.of("message", "Account deleted successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{id}/device-token")
    public ResponseEntity<?> saveDeviceToken(
            @PathVariable Long id,
            @RequestBody Map<String, String> request,
            HttpServletRequest httpRequest) {
        try {
            String deviceToken = request.get("deviceToken");
            if (deviceToken == null || deviceToken.isEmpty()) {
                return ResponseEntity.badRequest()
                    .body(Map.of("error", "Device token is required"));
            }

            Long userId = (Long) httpRequest.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            NotificationTokenRequest tokenRequest = new NotificationTokenRequest();
            tokenRequest.setUserId(id);
            tokenRequest.setFcmToken(deviceToken);
            tokenRequest.setPlatform(request.getOrDefault("platform", "MOBILE"));

            Student student = notificationTokenService.saveToken(tokenRequest);

            return ResponseEntity.ok(Map.of(
                "message", "Device token saved successfully",
                "deviceToken", student.getDeviceToken()
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{id}/device-token")
    public ResponseEntity<?> getDeviceToken(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("error", "User not authenticated"));
            }

            ownershipValidator.validateProfileOwnership(userId, id);

            Student student = studentRepo.findById(id)
                .orElseThrow(() -> new RuntimeException("Student not found"));

            return ResponseEntity.ok(Map.of(
                "deviceToken", student.getDeviceToken() != null
                    ? student.getDeviceToken()
                    : ""
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    private Student resolveViewer(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            return null;
        }
        try {
            return studentRepo.findById(Long.valueOf(userId.toString())).orElse(null);
        } catch (Exception ignored) {
            return null;
        }
    }
}

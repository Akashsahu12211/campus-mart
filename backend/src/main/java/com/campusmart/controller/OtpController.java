package com.campusmart.controller;

import com.campusmart.model.OtpVerification;
import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import com.campusmart.service.OtpService;
import com.campusmart.util.RateLimiter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/auth/otp")
public class OtpController {

    @Autowired
    private OtpService otpService;

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private RateLimiter rateLimiter;

    @Value("${app.expose-dev-otp:false}")
    private boolean exposeDevOtp;

    // ✅ REQUEST OTP - Email
    @PostMapping("/request-email")
    public ResponseEntity<?> requestEmailOtp(@RequestBody Map<String, String> request) {
        try {
            String email = request.get("email");
            if (email == null || email.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Email is required"));
            }

            if (!rateLimiter.allowOtpGeneration(email.trim().toLowerCase())) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(Map.of("error", "Too many OTP requests. Please try again later."));
            }

            // Check if email exists
            Optional<Student> student = studentRepository.findByEmail(email.trim().toLowerCase());
            if (student.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("error", "Email not registered"));
            }

            otpService.sendEmailOtp(student.get());
            return ResponseEntity.ok(Map.of(
                    "message", "OTP sent to " + email,
                    "expiresIn", "10 minutes"
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    // ✅ REQUEST OTP - Phone
    @PostMapping("/request-phone")
    public ResponseEntity<?> requestPhoneOtp(@RequestBody Map<String, String> request) {
        try {
            String phone = request.get("phone");
            if (phone == null || phone.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Phone is required"));
            }

            if (!rateLimiter.allowOtpGeneration(phone.trim())) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(Map.of("error", "Too many OTP requests. Please try again later."));
            }

            // Find student by phone
            Optional<Student> student = studentRepository.findAll().stream()
                    .filter(s -> s.getPhone() != null && s.getPhone().equals(phone.trim()))
                    .findFirst();

            if (student.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("error", "Phone number not registered"));
            }

            String otp = otpService.sendPhoneOtp(student.get());
            
            // For development: return OTP for testing
            Map<String, Object> response = new HashMap<>();
            response.put("message", "OTP sent to " + phone.trim());
            response.put("expiresIn", "10 minutes");
            if (exposeDevOtp) {
                response.put("otpForDevelopment", otp);
            }
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    // ✅ VERIFY OTP
    @PostMapping("/verify")
    public ResponseEntity<?> verifyOtp(HttpServletRequest httpRequest, @RequestBody Map<String, String> request) {
        try {
            // Get userId from Authorization header (set by AuthorizationFilter)
            Long userId = (Long) httpRequest.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "User not authenticated"));
            }

            String otpCode = request.get("otp");
            String otpTypeStr = request.get("type"); // "EMAIL" or "PHONE"

            if (otpCode == null || otpTypeStr == null) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "OTP code and type are required"));
            }

            if (!rateLimiter.allowOtpVerification(String.valueOf(userId))) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(Map.of("error", "Too many OTP verification attempts. Please try again later."));
            }

            OtpVerification.OtpType otpType = OtpVerification.OtpType.valueOf(otpTypeStr.toUpperCase());
            Optional<Student> student = studentRepository.findById(userId);
            if (student.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("error", "Student not found"));
            }

            boolean verified = otpService.verifyOtp(student.get(), otpCode, otpType);
            if (verified) {
                if (otpType == OtpVerification.OtpType.EMAIL) {
                    student.get().setEmailVerified(true);
                } else if (otpType == OtpVerification.OtpType.PHONE) {
                    student.get().setPhoneVerified(true);
                }
                studentRepository.save(student.get());
                return ResponseEntity.ok(Map.of(
                        "message", "OTP verified successfully",
                        "verified", true
                ));
            }

            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", "OTP verification failed"));

        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", e.getMessage()));
        }
    }

    // ✅ RESEND OTP
    @PostMapping("/resend")
    public ResponseEntity<?> resendOtp(HttpServletRequest httpRequest, @RequestBody Map<String, String> request) {
        try {
            Long userId = (Long) httpRequest.getAttribute("userId");
            if (userId == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("error", "User not authenticated"));
            }

            String otpTypeStr = request.get("type");
            if (otpTypeStr == null) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "OTP type is required"));
            }

            OtpVerification.OtpType otpType = OtpVerification.OtpType.valueOf(otpTypeStr.toUpperCase());
            Optional<Student> student = studentRepository.findById(userId);
            if (student.isEmpty()) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("error", "Student not found"));
            }

            if (otpType == OtpVerification.OtpType.EMAIL) {
                otpService.sendEmailOtp(student.get());
                return ResponseEntity.ok(Map.of("message", "OTP resent to " + student.get().getEmail()));
            } else if (otpType == OtpVerification.OtpType.PHONE) {
                String otp = otpService.sendPhoneOtp(student.get());
                Map<String, Object> response = new HashMap<>();
                response.put("message", "OTP resent to " + student.get().getPhone());
                if (exposeDevOtp) {
                    response.put("otpForDevelopment", otp);
                }
                return ResponseEntity.ok(response);
            }

            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Invalid OTP type"));

        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("error", e.getMessage()));
        }
    }
}

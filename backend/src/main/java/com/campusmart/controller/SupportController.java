package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.Student;
import com.campusmart.model.SupportRequest;
import com.campusmart.model.SupportRequest.SupportType;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.SupportRequestRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/support")
public class SupportController {

    @Autowired private SupportRequestRepository supportRepo;
    @Autowired private StudentRepository studentRepo;

    @PostMapping("/feedback")
    public ResponseEntity<?> submitFeedback(@RequestBody Map<String, Object> body) {
        return saveRequest(body, SupportType.FEEDBACK);
    }

    @PostMapping("/report-problem")
    public ResponseEntity<?> reportProblem(@RequestBody Map<String, Object> body) {
        return saveRequest(body, SupportType.PROBLEM_REPORT);
    }

    @PostMapping("/contact")
    public ResponseEntity<?> contactSupport(@RequestBody Map<String, Object> body) {
        return saveRequest(body, SupportType.CONTACT);
    }

    @GetMapping("/student/{studentId}")
    public ResponseEntity<?> getStudentSupportRequests(@PathVariable Long studentId) {
        try {
            SecurityUtils.requireCurrentUser(studentId);
            if (!studentRepo.existsById(studentId)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Student not found"));
            }
            return ResponseEntity.ok(supportRepo.findByStudentIdOrderByCreatedAtDesc(studentId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    private ResponseEntity<?> saveRequest(
        Map<String, Object> body,
        SupportType type
    ) {
        try {
            String name = String.valueOf(body.getOrDefault("name", "")).trim();
            String email = String.valueOf(body.getOrDefault("email", "")).trim();
            String subject = String.valueOf(body.getOrDefault("subject", "")).trim();
            String message = String.valueOf(body.getOrDefault("message", "")).trim();

            if (name.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Name is required"));
            }
            if (email.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Email is required"));
            }
            if (message.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Message is required"));
            }

            SupportRequest request = new SupportRequest();
            request.setType(type);
            request.setName(name);
            request.setEmail(email);
            request.setSubject(subject.isBlank() ? defaultSubject(type) : subject);
            request.setMessage(message);
            request.setCategory(String.valueOf(body.getOrDefault("category", "")).trim());
            request.setPagePath(String.valueOf(body.getOrDefault("pagePath", "")).trim());
            request.setAppPlatform(String.valueOf(body.getOrDefault("appPlatform", "web")).trim());

            Object studentId = body.get("studentId");
            Long authenticatedUserId = SecurityUtils.getOptionalCurrentUserId().orElse(null);
            if (studentId != null && !studentId.toString().isBlank()) {
                Long id = Long.valueOf(studentId.toString());
                if (authenticatedUserId == null || !authenticatedUserId.equals(id)) {
                    return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
                }
                Student student = studentRepo.findById(id)
                    .orElseThrow(() -> new RuntimeException("Student not found"));
                request.setStudent(student);
            } else {
                if (authenticatedUserId != null) {
                    studentRepo.findById(authenticatedUserId).ifPresent(request::setStudent);
                }
            }

            SupportRequest saved = supportRepo.save(request);
            return ResponseEntity.ok(Map.of(
                "message", "Request submitted successfully",
                "request", saved
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    private String defaultSubject(SupportType type) {
        return switch (type) {
            case FEEDBACK -> "Product Feedback";
            case PROBLEM_REPORT -> "Problem Report";
            case CONTACT -> "Support Request";
        };
    }
}

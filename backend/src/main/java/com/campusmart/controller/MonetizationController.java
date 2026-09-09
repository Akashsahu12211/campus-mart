package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import com.campusmart.service.MonetizationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/monetization")
public class MonetizationController {

    @Autowired private MonetizationService monetizationService;
    @Autowired private StudentRepository studentRepository;

    @GetMapping("/plans")
    public ResponseEntity<?> getPlans() {
        return ResponseEntity.ok(monetizationService.getPlans());
    }

    @GetMapping("/summary/{studentId}")
    public ResponseEntity<?> getSummary(@PathVariable Long studentId) {
        try {
            Long requesterId = SecurityUtils.getCurrentUserId();
            return ResponseEntity.ok(monetizationService.getSummary(requesterId, studentId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/ledger/{studentId}")
    public ResponseEntity<?> getLedger(@PathVariable Long studentId) {
        try {
            Long requesterId = SecurityUtils.getCurrentUserId();
            Map<String, Object> summary = monetizationService.getSummary(requesterId, studentId);
            return ResponseEntity.ok(summary.get("recentLedger"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/subscribe")
    public ResponseEntity<?> activatePlan(@RequestBody Map<String, Object> body) {
        try {
            Long studentId = SecurityUtils.getCurrentUserId();
            String planCode = body.getOrDefault("planCode", "FREE").toString();
            return ResponseEntity.ok(monetizationService.activatePlan(studentId, planCode));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/items/{itemId}/boost")
    public ResponseEntity<?> boostListing(@PathVariable Long itemId) {
        try {
            Long studentId = SecurityUtils.getCurrentUserId();
            Student seller = studentRepository.findById(studentId)
                .orElseThrow(() -> new RuntimeException("Seller not found"));
            if (Boolean.TRUE.equals(seller.getIsBanned())) {
                throw new RuntimeException("Banned users cannot boost listings");
            }
            return ResponseEntity.ok(monetizationService.boostListing(studentId, itemId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}

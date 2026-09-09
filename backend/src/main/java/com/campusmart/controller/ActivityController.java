package com.campusmart.controller;

import com.campusmart.service.ActivityService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/activity")
public class ActivityController {

    @Autowired private ActivityService activityService;

    @GetMapping("/{userId}")
    public ResponseEntity<?> getActivity(@PathVariable Long userId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(Map.of(
                "activities", activityService.getActivityHistory(userId)
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    private Long requireAuthenticatedUser(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("Unauthorized");
        }
        return Long.valueOf(userId.toString());
    }
}

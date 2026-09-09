package com.campusmart.controller;

import com.campusmart.dto.NotificationTokenRequest;
import com.campusmart.service.NotificationCenterService;
import com.campusmart.model.Student;
import com.campusmart.service.NotificationTokenService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationTokenService notificationTokenService;

    @Autowired
    private NotificationCenterService notificationCenterService;

    @PostMapping("/token")
    public ResponseEntity<?> saveNotificationToken(
            @RequestBody NotificationTokenRequest request,
            HttpServletRequest httpRequest) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(httpRequest);
            if (!authenticatedUserId.equals(request.getUserId())) {
                return ResponseEntity.status(403).body(Map.of("error", "Cannot update token for another user"));
            }

            Student updated = notificationTokenService.saveToken(request);
            return ResponseEntity.ok(Map.of(
                    "message", "Notification token saved successfully",
                    "userId", updated.getId(),
                    "platform", updated.getDevicePlatform() != null ? updated.getDevicePlatform() : "UNKNOWN"
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/token")
    public ResponseEntity<?> clearNotificationToken(
            @RequestBody NotificationTokenRequest request,
            HttpServletRequest httpRequest) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(httpRequest);
            if (!authenticatedUserId.equals(request.getUserId())) {
                return ResponseEntity.status(403).body(Map.of("error", "Cannot clear token for another user"));
            }

            Student updated = notificationTokenService.clearToken(request);
            return ResponseEntity.ok(Map.of(
                    "message", "Notification token cleared successfully",
                    "userId", updated.getId()
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{userId}")
    public ResponseEntity<?> getNotifications(@PathVariable Long userId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(Map.of(
                "notifications", notificationCenterService.getNotifications(userId),
                "unreadCount", notificationCenterService.getUnreadCount(userId)
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{userId}/{notificationId}/read")
    public ResponseEntity<?> markNotificationRead(
            @PathVariable Long userId,
            @PathVariable Long notificationId,
            HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(notificationCenterService.markRead(userId, notificationId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{userId}/read-all")
    public ResponseEntity<?> markAllNotificationsRead(@PathVariable Long userId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(Map.of("updated", notificationCenterService.markAllRead(userId)));
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

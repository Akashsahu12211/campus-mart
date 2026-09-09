package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.SiteSetting;
import com.campusmart.model.Student.StudentRole;
import com.campusmart.service.AdminService;
import com.campusmart.service.SiteAssetService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    @Autowired
    private AdminService adminService;

    @Autowired
    private SiteAssetService siteAssetService;

    @GetMapping("/stats")
    public ResponseEntity<?> getStats() {
        try {
            return ResponseEntity.ok(adminService.getDashboardStats());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/charts/users")
    public ResponseEntity<?> getUserGrowth() {
        try {
            return ResponseEntity.ok(adminService.getUserGrowthChart());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/charts/listings")
    public ResponseEntity<?> getListingsChart() {
        try {
            return ResponseEntity.ok(adminService.getListingsChart());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/charts/categories")
    public ResponseEntity<?> getCategoryDist() {
        try {
            return ResponseEntity.ok(adminService.getCategoryDistribution());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/users")
    public ResponseEntity<?> getAllUsers(@RequestParam(required = false) String search) {
        try {
            var users = (search != null && !search.isBlank())
                ? adminService.searchUsers(search)
                : adminService.getAllUsers();
            return ResponseEntity.ok(users);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/users/{targetId}/role")
    public ResponseEntity<?> changeRole(
        @PathVariable Long targetId,
        @RequestBody Map<String, Object> body) {
        try {
            StudentRole newRole = StudentRole.valueOf(body.get("role").toString().toUpperCase());
            return ResponseEntity.ok(
                adminService.changeUserRole(SecurityUtils.getCurrentUserId(), targetId, newRole)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/users/{targetId}/ban")
    public ResponseEntity<?> banUser(
        @PathVariable Long targetId,
        @RequestBody Map<String, Object> body) {
        try {
            String reason = body.get("reason") != null
                ? body.get("reason").toString()
                : "Violation of terms";
            return ResponseEntity.ok(
                adminService.banUser(SecurityUtils.getCurrentUserId(), targetId, reason)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/users/{targetId}/unban")
    public ResponseEntity<?> unbanUser(
        @PathVariable Long targetId,
        @RequestBody(required = false) Map<String, Long> body) {
        try {
            return ResponseEntity.ok(
                adminService.unbanUser(SecurityUtils.getCurrentUserId(), targetId)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/users/{targetId}")
    public ResponseEntity<?> deleteUser(@PathVariable Long targetId) {
        try {
            adminService.deleteUser(SecurityUtils.getCurrentUserId(), targetId);
            return ResponseEntity.ok(Map.of("message", "User deleted"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/items")
    public ResponseEntity<?> getAllItems(@RequestParam(required = false) String status) {
        try {
            var items = (status != null && !status.isBlank())
                ? adminService.getItemsByStatus(status)
                : adminService.getAllItemsAdmin();
            return ResponseEntity.ok(items);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/items/{itemId}/hide")
    public ResponseEntity<?> hideItem(
        @PathVariable Long itemId,
        @RequestBody Map<String, Object> body) {
        try {
            String reason = body.getOrDefault("reason", "Policy violation").toString();
            return ResponseEntity.ok(
                adminService.hideItem(SecurityUtils.getCurrentUserId(), itemId, reason)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/items/{itemId}/restore")
    public ResponseEntity<?> restoreItem(
        @PathVariable Long itemId,
        @RequestBody(required = false) Map<String, Long> body) {
        try {
            return ResponseEntity.ok(
                adminService.restoreItem(SecurityUtils.getCurrentUserId(), itemId)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/items/{itemId}")
    public ResponseEntity<?> deleteItem(@PathVariable Long itemId) {
        try {
            adminService.forceDeleteItem(SecurityUtils.getCurrentUserId(), itemId);
            return ResponseEntity.ok(Map.of("message", "Item deleted"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/reports")
    public ResponseEntity<?> getReports(@RequestParam(defaultValue = "false") boolean pendingOnly) {
        try {
            var reports = pendingOnly
                ? adminService.getPendingReports()
                : adminService.getAllReports();
            return ResponseEntity.ok(reports);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/reports/{reportId}")
    public ResponseEntity<?> reviewReport(
        @PathVariable Long reportId,
        @RequestBody Map<String, Object> body) {
        try {
            String action = body.get("action").toString();
            return ResponseEntity.ok(
                adminService.reviewReport(SecurityUtils.getCurrentUserId(), reportId, action)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/disputes")
    public ResponseEntity<?> getDisputes() {
        try {
            return ResponseEntity.ok(adminService.getDisputedPayments());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/disputes/{orderId}/resolve")
    public ResponseEntity<?> resolveDispute(
        @PathVariable Long orderId,
        @RequestBody Map<String, Object> body) {
        try {
            String action = body.get("action").toString();
            String reason = body.getOrDefault("reason", "Admin decision").toString();
            return ResponseEntity.ok(
                adminService.resolveDispute(SecurityUtils.getCurrentUserId(), orderId, action, reason)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/logs")
    public ResponseEntity<?> getLogs() {
        try {
            return ResponseEntity.ok(adminService.getRecentLogs());
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/support")
    public ResponseEntity<?> getSupportRequests(@RequestParam(required = false) String status) {
        try {
            return ResponseEntity.ok(adminService.getSupportRequests(status));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/support/{requestId}")
    public ResponseEntity<?> updateSupportStatus(
        @PathVariable Long requestId,
        @RequestBody Map<String, Object> body) {
        try {
            String status = body.get("status").toString();
            return ResponseEntity.ok(
                adminService.updateSupportRequestStatus(SecurityUtils.getCurrentUserId(), requestId, status)
            );
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/site-settings")
    public ResponseEntity<?> getSiteSettings() {
        try {
            return ResponseEntity.ok(adminService.getSiteSettings(SecurityUtils.getCurrentUserId()));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/site-settings")
    public ResponseEntity<?> updateSiteSettings(@RequestBody Map<String, Object> body) {
        try {
            SiteSetting saved = adminService.updateSiteSettings(SecurityUtils.getCurrentUserId(), body);
            return ResponseEntity.ok(saved);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/site-settings/cart-logo")
    public ResponseEntity<?> uploadCartLogo(@RequestParam("file") MultipartFile file) {
        try {
            adminService.getSiteSettings(SecurityUtils.getCurrentUserId());
            String relativeUrl = siteAssetService.storeCartLogo(file);
            String absoluteUrl = ServletUriComponentsBuilder.fromCurrentContextPath()
                .path(relativeUrl)
                .toUriString();
            return ResponseEntity.ok(Map.of(
                "cartLogoUrl", absoluteUrl,
                "relativePath", relativeUrl
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/maintenance/inline-item-images")
    public ResponseEntity<?> getInlineItemImageStats() {
        try {
            return ResponseEntity.ok(adminService.getInlineItemImageStats(SecurityUtils.getCurrentUserId()));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/maintenance/migrate-inline-item-images")
    public ResponseEntity<?> migrateInlineItemImages(@RequestParam(required = false) Integer limit) {
        try {
            return ResponseEntity.ok(adminService.migrateInlineItemImages(SecurityUtils.getCurrentUserId(), limit));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}

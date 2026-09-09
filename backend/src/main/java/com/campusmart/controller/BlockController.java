package com.campusmart.controller;

import com.campusmart.service.BlockService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/blocks")
public class BlockController {

    @Autowired private BlockService blockService;

    @PostMapping
    public ResponseEntity<?> blockUser(@RequestBody Map<String, Long> body, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            Long blockerId = body.get("blockerId");
            Long blockedId = body.get("blockedId");
            if (!authenticatedUserId.equals(blockerId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(blockService.blockUser(blockerId, blockedId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/{blockedId}")
    public ResponseEntity<?> unblockUser(@PathVariable Long blockedId, @RequestParam Long blockerId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(blockerId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            blockService.unblockUser(blockerId, blockedId);
            return ResponseEntity.ok(Map.of("message", "User unblocked"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/check")
    public ResponseEntity<?> checkBlockStatus(@RequestParam Long viewerId, @RequestParam Long targetUserId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(viewerId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(Map.of(
                "blocked", blockService.isBlockedByViewer(viewerId, targetUserId),
                "blockedEitherWay", blockService.isBlockedEitherWay(viewerId, targetUserId)
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{blockerId}")
    public ResponseEntity<?> getBlockedUsers(@PathVariable Long blockerId, HttpServletRequest request) {
        try {
            Long authenticatedUserId = requireAuthenticatedUser(request);
            if (!authenticatedUserId.equals(blockerId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(blockService.getBlockedUsers(blockerId));
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

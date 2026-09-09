package com.campusmart.controller;

import com.campusmart.config.AuthenticatedStudent;
import com.campusmart.model.Message;
import com.campusmart.service.ChatService;
import com.campusmart.util.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.List;
import java.util.Map;

@RestController
public class ChatController {

    @Autowired
    private ChatService chatService;

    @Autowired
    private RateLimiter rateLimiter;

    @MessageMapping("/chat.send")
    public void handleMessage(@Payload Map<String, Object> payload, Principal principal) {
        try {
            Long senderId = resolveMessagingUserId(principal);
            
            // ── Rate limiting per user ──
            if (!rateLimiter.allowSendMessage(String.valueOf(senderId))) {
                throw new RuntimeException("Rate limit exceeded for sending messages");
            }
            
            Long receiverId = Long.valueOf(payload.get("receiverId").toString());
            Long itemId = payload.get("itemId") != null
                ? Long.valueOf(payload.get("itemId").toString())
                : null;
            String content = payload.get("content").toString();

            // Validate receiver exists
            if (senderId.equals(receiverId)) {
                throw new RuntimeException("Cannot message yourself");
            }

            chatService.sendMessage(senderId, receiverId, itemId, content);
        } catch (Exception e) {
            System.err.println("WS Error in /chat.send: " + e.getMessage());
        }
    }

    @MessageMapping("/chat.typing")
    public void handleTyping(@Payload Map<String, Object> payload, Principal principal) {
        try {
            Long senderId = resolveMessagingUserId(principal);
            
            Long receiverId = Long.valueOf(payload.get("receiverId").toString());
            String name = payload.get("senderName") != null
                ? payload.get("senderName").toString()
                : "Someone";

            chatService.sendTypingIndicator(senderId, receiverId, name);
        } catch (Exception e) {
            System.err.println("WS Error in /chat.typing: " + e.getMessage());
        }
    }

    @GetMapping("/api/chat/conversation")
    public ResponseEntity<List<Message>> getConversation(
            @RequestParam Long user1Id,
            @RequestParam Long user2Id,
            @RequestParam(required = false) Long itemId,
            HttpServletRequest request) {
        Long userId = requireAuthenticatedUser(request);
        if (!userId.equals(user1Id) && !userId.equals(user2Id)) {
            throw new RuntimeException("Unauthorized");
        }
        return ResponseEntity.ok(chatService.getConversation(user1Id, user2Id, itemId));
    }

    @GetMapping("/api/chat/inbox/{userId}")
    public ResponseEntity<?> getInbox(
            @PathVariable Long userId,
            HttpServletRequest request) {
        try {
            requireSameUser(request, userId);
            return ResponseEntity.ok(chatService.getInbox(userId));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/api/chat/send")
    public ResponseEntity<?> sendMessage(
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        try {
            Long senderId = Long.valueOf(body.get("senderId").toString());
            requireSameUser(request, senderId);

            Long receiverId = Long.valueOf(body.get("receiverId").toString());
            Long itemId = body.get("itemId") != null
                ? Long.valueOf(body.get("itemId").toString())
                : null;
            String content = body.get("content").toString();

            Message msg = chatService.sendMessage(senderId, receiverId, itemId, content);
            return ResponseEntity.ok(msg);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/api/chat/mark-read")
    public ResponseEntity<?> markAsRead(
            @RequestBody Map<String, Long> body,
            HttpServletRequest request) {
        requireSameUser(request, body.get("receiverId"));
        chatService.markAsRead(body.get("receiverId"), body.get("senderId"));
        return ResponseEntity.ok(Map.of("message", "Marked as read"));
    }

    @GetMapping("/api/chat/unread/{userId}")
    public ResponseEntity<Map<String, Long>> getUnreadCount(
            @PathVariable Long userId,
            HttpServletRequest request) {
        requireSameUser(request, userId);
        return ResponseEntity.ok(Map.of("count", chatService.getUnreadCount(userId)));
    }

    private Long requireAuthenticatedUser(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("Unauthorized");
        }
        return Long.valueOf(userId.toString());
    }

    private void requireSameUser(HttpServletRequest request, Long expectedUserId) {
        if (!requireAuthenticatedUser(request).equals(expectedUserId)) {
            throw new RuntimeException("Unauthorized");
        }
    }

    private Long resolveMessagingUserId(Principal principal) {
        if (principal instanceof UsernamePasswordAuthenticationToken authentication
                && authentication.getPrincipal() instanceof AuthenticatedStudent authenticatedStudent) {
            return authenticatedStudent.getId();
        }
        throw new RuntimeException("Unauthorized");
    }
}

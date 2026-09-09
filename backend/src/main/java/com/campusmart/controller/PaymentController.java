package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.service.AdminService;
import com.campusmart.service.PaymentService;
import com.campusmart.util.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/payments")
public class PaymentController {

    @Autowired private PaymentService paymentService;
    @Autowired private AdminService adminService;
    @Autowired private RateLimiter rateLimiter;

    @PostMapping("/create-order")
    public ResponseEntity<?> createOrder(
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        try {
            Long buyerId = requireAuthenticatedUser(request);
            
            // ── Rate limiting per user ──
            if (!rateLimiter.allowCreateOrder(String.valueOf(buyerId))) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many payment order creation attempts. Please try again later."
                ));
            }
            
            Long itemId = Long.valueOf(body.get("itemId").toString());
            BigDecimal amount = body.get("amount") != null
                    ? new BigDecimal(body.get("amount").toString())
                    : null;
            String notes = body.get("notes") != null ? body.get("notes").toString() : null;

            return ResponseEntity.ok(paymentService.createOrder(buyerId, itemId, amount, notes));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/verify")
    public ResponseEntity<?> verifyPayment(
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        try {
            Long buyerId = requireAuthenticatedUser(request);
            String orderId = body.get("razorpayOrderId").toString();
            String paymentId = body.get("razorpayPaymentId").toString();
            String signature = body.get("razorpaySignature").toString();

            return ResponseEntity.ok(
                paymentService.verifyPayment(orderId, paymentId, signature, buyerId)
            );
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{orderId}/confirm-delivery")
    public ResponseEntity<?> confirmDelivery(
            @PathVariable Long orderId,
            @RequestBody(required = false) Map<String, Long> body,
            HttpServletRequest request) {
        try {
            Long buyerId = requireAuthenticatedUser(request);
            return ResponseEntity.ok(paymentService.confirmDelivery(orderId, buyerId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{orderId}/dispute")
    public ResponseEntity<?> raiseDispute(
            @PathVariable Long orderId,
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        try {
            Long buyerId = requireAuthenticatedUser(request);
            String reason = body.getOrDefault("reason", "Item not received").toString();
            return ResponseEntity.ok(paymentService.raiseDispute(orderId, buyerId, reason));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{orderId}/cancel")
    public ResponseEntity<?> cancelOrder(
            @PathVariable Long orderId,
            @RequestBody(required = false) Map<String, Long> body,
            HttpServletRequest request) {
        try {
            Long buyerId = requireAuthenticatedUser(request);
            return ResponseEntity.ok(paymentService.cancelOrder(orderId, buyerId));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/buyer/{buyerId}")
    public ResponseEntity<?> getBuyerOrders(
            @PathVariable Long buyerId,
            HttpServletRequest request) {
        try {
            requireSameUser(request, buyerId);
            return ResponseEntity.ok(paymentService.getBuyerOrders(buyerId));
        } catch (RuntimeException e) {
            return ResponseEntity.status(403).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/seller/{sellerId}")
    public ResponseEntity<?> getSellerOrders(
            @PathVariable Long sellerId,
            HttpServletRequest request) {
        try {
            requireSameUser(request, sellerId);
            return ResponseEntity.ok(paymentService.getSellerOrders(sellerId));
        } catch (RuntimeException e) {
            return ResponseEntity.status(403).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{orderId}/timeline")
    public ResponseEntity<?> getTimeline(
            @PathVariable Long orderId,
            HttpServletRequest request) {
        try {
            Long userId = requireAuthenticatedUser(request);
            var order = paymentService.getOrderById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
            boolean isParticipant = order.getBuyer().getId().equals(userId)
                || order.getSeller().getId().equals(userId);
            if (!isParticipant) {
                throw new RuntimeException("Unauthorized access");
            }
            return ResponseEntity.ok(paymentService.getOrderTimeline(orderId));
        } catch (Exception e) {
            return ResponseEntity.status(403).body(Map.of("error", "Unauthorized access"));
        }
    }

    @GetMapping("/config")
    public ResponseEntity<Map<String, Object>> getConfig() {
        return ResponseEntity.ok(paymentService.getGatewayConfig());
    }

    @PostMapping("/webhooks/razorpay")
    public ResponseEntity<?> handleRazorpayWebhook(
            @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature,
            @RequestBody String payload
    ) {
        try {
            return ResponseEntity.ok(paymentService.handleWebhook(payload, signature));
        } catch (RuntimeException e) {
            return ResponseEntity.status(401).body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{orderId}/refund")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> refundOrder(
            @PathVariable Long orderId,
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        try {
            Long adminId = requireAuthenticatedUser(request);
            adminService.requireAdmin(adminId);
            String reason = body.getOrDefault("reason", "Admin refund").toString();
            return ResponseEntity.ok(paymentService.refundOrder(orderId, adminId, reason));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    private Long requireAuthenticatedUser(HttpServletRequest request) {
        return SecurityUtils.getCurrentUserId();
    }

    private void requireSameUser(HttpServletRequest request, Long expectedUserId) {
        Long actualUserId = requireAuthenticatedUser(request);
        if (!actualUserId.equals(expectedUserId)) {
            throw new RuntimeException("Unauthorized access");
        }
    }
}

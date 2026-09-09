package com.campusmart.security;

import com.campusmart.model.ApiRateLimitWindow;
import com.campusmart.repository.ApiRateLimitWindowRepository;
import com.campusmart.util.RateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;

@DisplayName("Rate Limiting Security Tests")
public class RateLimitingSecurityTests {

    private RateLimiter rateLimiter;

    @BeforeEach
    public void setUp() {
        ApiRateLimitWindowRepository repository = Mockito.mock(ApiRateLimitWindowRepository.class);
        Map<String, ApiRateLimitWindow> windows = new ConcurrentHashMap<>();

        Mockito.when(repository.findByRateKey(anyString()))
            .thenAnswer(invocation -> Optional.ofNullable(windows.get(invocation.getArgument(0))));

        Mockito.when(repository.save(any(ApiRateLimitWindow.class)))
            .thenAnswer(invocation -> {
                ApiRateLimitWindow window = invocation.getArgument(0);
                windows.put(window.getRateKey(), window);
                return window;
            });

        Mockito.doAnswer(invocation -> {
            windows.remove(invocation.getArgument(0));
            return null;
        }).when(repository).deleteByRateKey(anyString());

        Mockito.doAnswer(invocation -> {
            LocalDateTime cutoff = invocation.getArgument(0);
            windows.entrySet().removeIf(entry ->
                entry.getValue().getExpiresAt() != null && entry.getValue().getExpiresAt().isBefore(cutoff)
            );
            return 0;
        }).when(repository).deleteExpiredBefore(any(LocalDateTime.class));

        Mockito.when(repository.findTop200ByOrderByUpdatedAtDesc())
            .thenAnswer(invocation -> new ArrayList<>(windows.values()).stream()
                .sorted(Comparator.comparing(ApiRateLimitWindow::getUpdatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(200)
                .toList());

        Mockito.doAnswer(invocation -> {
            windows.clear();
            return null;
        }).when(repository).deleteAllInBatch();

        rateLimiter = new RateLimiter(repository);
    }

    @Test
    @DisplayName("Login rate limit allows 5 attempts per minute")
    public void testLoginRateLimitAllowsFirstFiveAttempts() {
        String userId = "192.168.1.1";

        for (int i = 0; i < 5; i++) {
            assertTrue(rateLimiter.allowLogin(userId),
                "Login attempt " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowLogin(userId),
            "6th login attempt should be blocked (rate limit exceeded)");
    }

    @Test
    @DisplayName("OTP generation rate limit allows 3 attempts per 30 minutes")
    public void testOtpGenerationRateLimitEnforcement() {
        String email = "test@example.com";

        for (int i = 0; i < 3; i++) {
            assertTrue(rateLimiter.allowOtpGeneration(email),
                "OTP generation attempt " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowOtpGeneration(email),
            "4th OTP generation attempt should be blocked");
    }

    @Test
    @DisplayName("OTP verification rate limit allows 5 attempts per 15 minutes")
    public void testOtpVerificationRateLimitEnforcement() {
        String email = "verify@example.com";

        for (int i = 0; i < 5; i++) {
            assertTrue(rateLimiter.allowOtpVerification(email),
                "OTP verification attempt " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowOtpVerification(email),
            "6th OTP verification attempt should be blocked");
    }

    @Test
    @DisplayName("Message sending rate limit allows 50 per minute per user")
    public void testMessageSendingRateLimit() {
        String userId = "user123";

        for (int i = 0; i < 50; i++) {
            assertTrue(rateLimiter.allowSendMessage(userId),
                "Message " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowSendMessage(userId),
            "51st message should be blocked (rate limit exceeded)");
    }

    @Test
    @DisplayName("Payment order creation rate limit allows 10 per minute")
    public void testPaymentOrderRateLimit() {
        String userId = "buyer456";

        for (int i = 0; i < 10; i++) {
            assertTrue(rateLimiter.allowCreateOrder(userId),
                "Order " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowCreateOrder(userId),
            "11th order should be blocked");
    }

    @Test
    @DisplayName("Item creation rate limit allows 30 per hour")
    public void testItemCreationRateLimit() {
        String userId = "seller789";

        for (int i = 0; i < 30; i++) {
            assertTrue(rateLimiter.allowCreateItem(userId),
                "Item " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowCreateItem(userId),
            "31st item should be blocked");
    }

    @Test
    @DisplayName("Offer creation rate limit allows 20 per hour")
    public void testOfferCreationRateLimit() {
        String userId = "offermaker";

        for (int i = 0; i < 20; i++) {
            assertTrue(rateLimiter.allowCreateOffer(userId),
                "Offer " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowCreateOffer(userId),
            "21st offer should be blocked");
    }

    @Test
    @DisplayName("Different users have independent rate limits")
    public void testRateLimitsArePerUser() {
        String user1 = "user1";
        String user2 = "user2";

        for (int i = 0; i < 5; i++) {
            rateLimiter.allowLogin(user1);
        }

        assertTrue(rateLimiter.allowLogin(user2),
            "User2 should not be affected by user1's rate limit");
    }

    @Test
    @DisplayName("Password reset rate limit allows 3 per hour")
    public void testPasswordResetRateLimit() {
        String email = "reset@example.com";

        for (int i = 0; i < 3; i++) {
            assertTrue(rateLimiter.allowPasswordReset(email),
                "Password reset " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.allowPasswordReset(email),
            "4th password reset should be blocked");
    }

    @Test
    @DisplayName("Get remaining tokens reflects accurate count")
    public void testGetRemainingTokens() {
        String userId = "user_tokens";

        rateLimiter.allowLogin(userId);
        rateLimiter.allowLogin(userId);
        rateLimiter.allowLogin(userId);

        long remaining = rateLimiter.getRemainingTokens(userId, "login");
        assertEquals(2, remaining, "Should have 2 remaining tokens after 3 uses");
    }
}

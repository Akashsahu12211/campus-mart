package com.campusmart.util;

import com.campusmart.model.ApiRateLimitWindow;
import com.campusmart.repository.ApiRateLimitWindowRepository;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Rate Limiter utility for protecting API endpoints from abuse
 * Uses Token Bucket algorithm via Bucket4j
 */
@Component
public class RateLimiter {

    private static final long CLEANUP_INTERVAL_MS = 15 * 60 * 1000L;

    private final ApiRateLimitWindowRepository repository;
    private final Map<String, ApiRateLimitWindow> fallbackWindows = new ConcurrentHashMap<>();
    private final AtomicLong lastCleanupAtMs = new AtomicLong(0L);

    @Autowired
    public RateLimiter(ObjectProvider<ApiRateLimitWindowRepository> repositoryProvider) {
        this(repositoryProvider.getIfAvailable());
    }

    public RateLimiter(ApiRateLimitWindowRepository repository) {
        this.repository = repository;
    }
    
    // ========================================
    // RATE LIMIT CONFIGURATIONS
    // ========================================
    
    /**
     * Auth Login: 5 attempts per minute per IP
     */
    @Transactional
    public boolean allowLogin(String identifier) {
        return checkLimit(identifier, "login", 5, 1);
    }
    
    /**
     * OTP Generation: 3 attempts per 30 minutes per email
     */
    @Transactional
    public boolean allowOtpGeneration(String identifier) {
        return checkLimit(identifier, "otp-gen", 3, 30);
    }
    
    /**
     * OTP Verification: 5 attempts per 15 minutes per email
     */
    @Transactional
    public boolean allowOtpVerification(String identifier) {
        return checkLimit(identifier, "otp-verify", 5, 15);
    }
    
    /**
     * Password Reset: 3 attempts per hour per email
     */
    @Transactional
    public boolean allowPasswordReset(String identifier) {
        return checkLimit(identifier, "password-reset", 3, 60);
    }
    
    /**
     * Create Payment Order: 10 attempts per minute per user
     */
    @Transactional
    public boolean allowCreateOrder(String identifier) {
        return checkLimit(identifier, "create-order", 10, 1);
    }
    
    /**
     * Create Item: 30 items per hour per user
     */
    @Transactional
    public boolean allowCreateItem(String identifier) {
        return checkLimit(identifier, "create-item", 30, 60);
    }
    
    /**
     * Send Message: 50 messages per minute per user
     */
    @Transactional
    public boolean allowSendMessage(String identifier) {
        return checkLimit(identifier, "send-message", 50, 1);
    }
    
    /**
     * Create Offer: 20 offers per hour per user
     */
    @Transactional
    public boolean allowCreateOffer(String identifier) {
        return checkLimit(identifier, "create-offer", 20, 60);
    }
    
    /**
     * Generic rate limit check
     * @param identifier Unique identifier (IP, user ID, email, etc.)
     * @param action Action name for cache key
     * @param requests Number of allowed requests
     * @param minutes Time window in minutes
     * @return true if request is allowed, false if rate limit exceeded
     */
    private boolean checkLimit(String identifier, String action, int requests, int minutes) {
        cleanupExpiredWindows();

        String normalizedIdentifier = normalizeIdentifier(identifier);
        String key = action + ":" + hashIdentifier(normalizedIdentifier);
        LocalDateTime now = LocalDateTime.now();

        ApiRateLimitWindow window = repository != null
            ? repository.findByRateKey(key).orElse(null)
            : fallbackWindows.get(key);
        if (window == null) {
            ApiRateLimitWindow newWindow = new ApiRateLimitWindow();
            newWindow.setRateKey(key);
            newWindow.setActionName(action);
            newWindow.setWindowMinutes(minutes);
            newWindow.setLimitCount(requests);
            newWindow.setRequestCount(1);
            newWindow.setWindowStartedAt(now);
            newWindow.setExpiresAt(now.plusMinutes(minutes));
            newWindow.setUpdatedAt(now);
            saveWindow(newWindow);
            return true;
        }

        if (window.getExpiresAt() == null || !window.getExpiresAt().isAfter(now)) {
            window.setWindowMinutes(minutes);
            window.setLimitCount(requests);
            window.setRequestCount(1);
            window.setWindowStartedAt(now);
            window.setExpiresAt(now.plusMinutes(minutes));
            saveWindow(window);
            return true;
        }

        if (window.getRequestCount() >= requests) {
            return false;
        }

        window.setLimitCount(requests);
        window.setWindowMinutes(minutes);
        window.setRequestCount(window.getRequestCount() + 1);
        saveWindow(window);
        return true;
    }
    
    /**
     * Get remaining tokens for a specific rate limit
     * @return remaining tokens, or -1 if bucket doesn't exist
     */
    public long getRemainingTokens(String identifier, String action) {
        String key = action + ":" + hashIdentifier(normalizeIdentifier(identifier));
        ApiRateLimitWindow window = repository != null
            ? repository.findByRateKey(key).orElse(null)
            : fallbackWindows.get(key);

        if (window == null) {
            return -1;
        }

        if (window.getExpiresAt() == null || !window.getExpiresAt().isAfter(LocalDateTime.now())) {
            return window.getLimitCount();
        }

        return Math.max(0, window.getLimitCount() - window.getRequestCount());
    }
    
    /**
     * Clear rate limit for a specific identifier (admin use only)
     */
    public void clearLimit(String identifier, String action) {
        String key = action + ":" + hashIdentifier(normalizeIdentifier(identifier));
        if (repository != null) {
            repository.deleteByRateKey(key);
        } else {
            fallbackWindows.remove(key);
        }
    }
    
    /**
     * Clear all rate limits (use carefully)
     */
    public void clearAllLimits() {
        if (repository != null) {
            repository.deleteAllInBatch();
        } else {
            fallbackWindows.clear();
        }
    }
    
    /**
     * Get bucket statistics for monitoring
     */
    public Map<String, Long> getStats() {
        Map<String, Long> stats = new ConcurrentHashMap<>();
        Iterable<ApiRateLimitWindow> windows = repository != null
            ? repository.findTop200ByOrderByUpdatedAtDesc()
            : fallbackWindows.values();
        windows.forEach(window ->
            stats.put(window.getRateKey(), (long) Math.max(0, window.getLimitCount() - window.getRequestCount()))
        );
        return stats;
    }

    private void cleanupExpiredWindows() {
        long now = System.currentTimeMillis();
        long lastCleanup = lastCleanupAtMs.get();
        if (now - lastCleanup < CLEANUP_INTERVAL_MS) {
            return;
        }
        if (lastCleanupAtMs.compareAndSet(lastCleanup, now)) {
            if (repository != null) {
                repository.deleteExpiredBefore(LocalDateTime.now().minusDays(1));
            } else {
                LocalDateTime cutoff = LocalDateTime.now().minusDays(1);
                fallbackWindows.entrySet().removeIf(entry ->
                    entry.getValue().getExpiresAt() != null && entry.getValue().getExpiresAt().isBefore(cutoff)
                );
            }
        }
    }

    private void saveWindow(ApiRateLimitWindow window) {
        if (repository != null) {
            repository.save(window);
        } else {
            fallbackWindows.put(window.getRateKey(), window);
        }
    }

    private String normalizeIdentifier(String identifier) {
        if (identifier == null) {
            return "anonymous";
        }
        String trimmed = identifier.trim().toLowerCase();
        return trimmed.isEmpty() ? "anonymous" : trimmed;
    }

    private String hashIdentifier(String identifier) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(identifier.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is not available", e);
        }
    }
}

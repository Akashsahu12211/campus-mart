package com.campusmart.service;

import com.campusmart.model.ApiRateLimitWindow;
import com.campusmart.repository.ApiRateLimitWindowRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

/**
 * Rate limit service using fixed window algorithm
 * Tracks requests per client per action (AUTH, API, etc.)
 */
@Service
public class RateLimitService {

    @Autowired
    private ApiRateLimitWindowRepository rateLimitRepo;

    @Transactional
    public synchronized boolean allowRequest(String clientKey, String actionName, int limitPerMinute) {
        LocalDateTime now = LocalDateTime.now();
        
        // Create composite rate key: clientId:action
        String rateKey = clientKey + ":" + actionName;
        
        // Try to get existing window
        Optional<ApiRateLimitWindow> existingWindow = rateLimitRepo.findByRateKey(rateKey);
        
        ApiRateLimitWindow window;
        if (existingWindow.isPresent()) {
            window = existingWindow.get();
            
            // Check if window has expired
            if (now.isAfter(window.getExpiresAt())) {
                // Window expired, reset
                window.setRequestCount(1);
                window.setWindowStartedAt(now);
                window.setExpiresAt(now.plusMinutes(1));
            } else {
                // Still in window
                int currentCount = window.getRequestCount();
                if (currentCount >= limitPerMinute) {
                    return false; // Exceeded limit
                }
                window.setRequestCount(currentCount + 1);
            }
        } else {
            // New window
            window = new ApiRateLimitWindow();
            window.setRateKey(rateKey);
            window.setActionName(actionName);
            window.setWindowMinutes(1);
            window.setLimitCount(limitPerMinute);
            window.setRequestCount(1);
            window.setWindowStartedAt(now);
            window.setExpiresAt(now.plusMinutes(1));
        }
        
        rateLimitRepo.save(window);
        
        // Clean up expired windows (older than 5 minutes)
        LocalDateTime fiveMinutesAgo = now.minusMinutes(5);
        rateLimitRepo.deleteExpiredBefore(fiveMinutesAgo);
        
        return true;
    }
}

package com.campusmart.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

/**
 * Utility for extracting client IP address from HTTP requests
 * Handles proxy scenarios, X-Forwarded-For headers, and direct connections
 */
@Component
public class ServletUtils {
    
    /**
     * Extract client IP address from HTTP request
     * Checks multiple headers to handle proxy scenarios
     * 
     * @param request HttpServletRequest
     * @return Client IP address or "unknown" if cannot be determined
     */
    public static String getClientIp(HttpServletRequest request) {
        // Check X-Forwarded-For (for requests through proxies)
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty() && 
            !xForwardedFor.equalsIgnoreCase("unknown")) {
            // X-Forwarded-For can contain multiple IPs (comma-separated)
            // Take the first one (original client)
            return xForwardedFor.split(",")[0].trim();
        }
        
        // Check X-Real-IP (for requests through Nginx or other proxies)
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty() && 
            !xRealIp.equalsIgnoreCase("unknown")) {
            return xRealIp;
        }
        
        // Check CF-Connecting-IP (for Cloudflare)
        String cfIp = request.getHeader("CF-Connecting-IP");
        if (cfIp != null && !cfIp.isEmpty() && 
            !cfIp.equalsIgnoreCase("unknown")) {
            return cfIp;
        }
        
        // Direct connection - get from request
        String remoteAddr = request.getRemoteAddr();
        if (remoteAddr != null && !remoteAddr.isEmpty() && 
            !remoteAddr.equalsIgnoreCase("unknown")) {
            return remoteAddr;
        }
        
        // Fallback
        return "unknown";
    }
    
    /**
     * Validate IP address format (basic check)
     * @param ip IP address string
     * @return true if valid IPv4 format
     */
    public static boolean isValidIp(String ip) {
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            return false;
        }
        
        String[] parts = ip.split("\\.");
        if (parts.length != 4) {
            return false;
        }
        
        for (String part : parts) {
            try {
                int num = Integer.parseInt(part);
                if (num < 0 || num > 255) {
                    return false;
                }
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Anonymize IP for logging/analytics (keep first 2 octets)
     * Example: 192.168.1.45 → 192.168.x.x
     * @param ip Full IP address
     * @return Anonymized IP
     */
    public static String anonymizeIp(String ip) {
        if (ip == null || !isValidIp(ip)) {
            return "unknown";
        }
        
        String[] parts = ip.split("\\.");
        return parts[0] + "." + parts[1] + ".x.x";
    }
}

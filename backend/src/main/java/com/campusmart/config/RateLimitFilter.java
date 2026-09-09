package com.campusmart.config;

import com.campusmart.service.RateLimitService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Global rate limiting filter to prevent abuse
 * Applied to all API endpoints
 * Limits: 100 req/min for general endpoints, 5 req/min for auth endpoints
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    @Autowired(required = false)
    private RateLimitService rateLimitService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        if (rateLimitService == null) {
            filterChain.doFilter(request, response);
            return;
        }

        String clientKey = extractClientKey(request);
        String path = request.getServletPath();
        
        // Stricter limit for auth endpoints
        String actionName = path.contains("/auth") ? "AUTH" : "API";
        int limitPerMinute = actionName.equals("AUTH") ? 5 : 100;
        
        if (!rateLimitService.allowRequest(clientKey, actionName, limitPerMinute)) {
            response.setStatus(429); // SC_TOO_MANY_REQUESTS (not available in jakarta.servlet)
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Rate limit exceeded. Max " + limitPerMinute + " requests/minute\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String extractClientKey(HttpServletRequest request) {
        Object requestUserId = request.getAttribute("userId");
        if (requestUserId != null) {
            return "user_" + requestUserId;
        }

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof AuthenticatedStudent authenticatedStudent) {
            return "user_" + authenticatedStudent.getId();
        }

        String clientIp = request.getHeader("X-Forwarded-For");
        if (clientIp == null || clientIp.isEmpty()) {
            clientIp = request.getRemoteAddr();
        }
        if (clientIp.contains(",")) {
            clientIp = clientIp.split(",")[0].trim();
        }
        return "ip_" + clientIp;
    }
}

package com.campusmart.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;

@Component
public class SecureTransportEnforcementFilter extends OncePerRequestFilter {

    private final ObjectMapper objectMapper;

    @Value("${app.require-secure-transport:false}")
    private boolean requireSecureTransport;

    public SecureTransportEnforcementFilter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        if (!requireSecureTransport || isSecureRequest(request) || isLoopbackRequest(request)) {
            filterChain.doFilter(request, response);
            return;
        }

        response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
        response.setContentType("application/json");
        objectMapper.writeValue(response.getWriter(), Map.of(
                "error", "Secure HTTPS or WSS transport is required for this environment."
        ));
    }

    private boolean isSecureRequest(HttpServletRequest request) {
        if (request.isSecure()) {
            return true;
        }
        String forwardedProto = request.getHeader("X-Forwarded-Proto");
        return forwardedProto != null && "https".equalsIgnoreCase(forwardedProto.trim());
    }

    private boolean isLoopbackRequest(HttpServletRequest request) {
        String host = request.getServerName();
        return "localhost".equalsIgnoreCase(host)
                || "127.0.0.1".equals(host)
                || "0:0:0:0:0:0:0:1".equals(host)
                || "::1".equals(host);
    }
}

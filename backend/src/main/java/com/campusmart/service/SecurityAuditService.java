package com.campusmart.service;

import com.campusmart.model.SecurityAuditLog;
import com.campusmart.repository.SecurityAuditLogRepository;
import com.campusmart.util.ServletUtils;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;

@Service
public class SecurityAuditService {

    private final SecurityAuditLogRepository securityAuditLogRepository;

    public SecurityAuditService(SecurityAuditLogRepository securityAuditLogRepository) {
        this.securityAuditLogRepository = securityAuditLogRepository;
    }

    public void record(HttpServletRequest request, Long studentId, String eventType, boolean success, String details) {
        String ipAddress = request == null ? "unknown" : ServletUtils.getClientIp(request);
        String userAgent = request == null ? null : request.getHeader("User-Agent");
        save(studentId, eventType, success, ipAddress, userAgent, details);
    }

    public void save(Long studentId, String eventType, boolean success, String ipAddress, String userAgent, String details) {
        try {
            SecurityAuditLog entry = new SecurityAuditLog();
            entry.setStudentId(studentId);
            entry.setEventType(trim(eventType, 64));
            entry.setSuccess(success);
            entry.setIpAddressMasked(ServletUtils.anonymizeIp(ipAddress));
            entry.setUserAgent(trim(userAgent, 255));
            entry.setDetails(trim(details, 500));
            securityAuditLogRepository.save(entry);
        } catch (Exception ignored) {
            // Never block the primary auth/security flow because of audit persistence.
        }
    }

    private String trim(String value, int maxLength) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        if (normalized.length() <= maxLength) {
            return normalized;
        }
        return normalized.substring(0, maxLength);
    }
}

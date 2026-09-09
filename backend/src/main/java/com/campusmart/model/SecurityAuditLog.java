package com.campusmart.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "security_audit_logs",
    indexes = {
        @Index(name = "idx_security_audit_created_at", columnList = "created_at"),
        @Index(name = "idx_security_audit_student_event", columnList = "student_id, event_type")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SecurityAuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "student_id")
    private Long studentId;

    @Column(name = "event_type", nullable = false, length = 64)
    private String eventType;

    @Column(nullable = false)
    private Boolean success = Boolean.TRUE;

    @Column(name = "ip_address_masked", length = 64)
    private String ipAddressMasked;

    @Column(name = "user_agent", length = 255)
    private String userAgent;

    @Column(name = "details", length = 500)
    private String details;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
}

package com.campusmart.repository;

import com.campusmart.model.SecurityAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SecurityAuditLogRepository extends JpaRepository<SecurityAuditLog, Long> {
    List<SecurityAuditLog> findTop100ByOrderByCreatedAtDesc();
}

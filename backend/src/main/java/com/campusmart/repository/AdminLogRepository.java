package com.campusmart.repository;

import com.campusmart.model.AdminLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface AdminLogRepository
    extends JpaRepository<AdminLog, Long> {
    List<AdminLog> findTop50ByOrderByCreatedAtDesc();
    List<AdminLog> findByAdminIdOrderByCreatedAtDesc(Long adminId);
}

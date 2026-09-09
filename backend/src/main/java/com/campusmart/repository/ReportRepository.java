package com.campusmart.repository;

import com.campusmart.model.Report;
import com.campusmart.model.Report.ReportStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ReportRepository
    extends JpaRepository<Report, Long> {
    List<Report> findByStatusOrderByCreatedAtDesc(ReportStatus s);
    List<Report> findAllByOrderByCreatedAtDesc();
    long countByStatus(ReportStatus status);
    long countByItemId(Long itemId);
    long countByItemIdAndStatus(Long itemId, ReportStatus status);
    boolean existsByReporterIdAndItemId(Long reporterId, Long itemId);
}

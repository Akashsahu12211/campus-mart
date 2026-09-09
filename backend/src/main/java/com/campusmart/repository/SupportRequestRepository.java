package com.campusmart.repository;

import com.campusmart.model.SupportRequest;
import com.campusmart.model.SupportRequest.SupportStatus;
import com.campusmart.model.SupportRequest.SupportType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SupportRequestRepository extends JpaRepository<SupportRequest, Long> {

    List<SupportRequest> findAllByOrderByCreatedAtDesc();

    List<SupportRequest> findByStudentIdOrderByCreatedAtDesc(Long studentId);

    List<SupportRequest> findByStatusOrderByCreatedAtDesc(SupportStatus status);

    long countByStatus(SupportStatus status);

    long countByType(SupportType type);
}

package com.campusmart.repository;

import com.campusmart.model.SubscriptionRecord;
import com.campusmart.model.SubscriptionRecord.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SubscriptionRecordRepository extends JpaRepository<SubscriptionRecord, Long> {

    List<SubscriptionRecord> findByStudentIdOrderByStartedAtDesc(Long studentId);

    Optional<SubscriptionRecord> findTopByStudentIdAndStatusOrderByStartedAtDesc(
        Long studentId,
        SubscriptionStatus status
    );

    List<SubscriptionRecord> findByStatus(SubscriptionStatus status);
}

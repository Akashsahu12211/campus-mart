package com.campusmart.repository;

import com.campusmart.model.NotificationEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationEntryRepository extends JpaRepository<NotificationEntry, Long> {

    List<NotificationEntry> findTop50ByStudentIdOrderByCreatedAtDesc(Long studentId);

    long countByStudentIdAndIsReadFalse(Long studentId);
}

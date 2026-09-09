package com.campusmart.repository;

import com.campusmart.model.StudentFcmToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface StudentFcmTokenRepository extends JpaRepository<StudentFcmToken, Long> {

    Optional<StudentFcmToken> findByFcmToken(String fcmToken);

    List<StudentFcmToken> findByStudentId(Long studentId);

    void deleteByStudentIdAndFcmToken(Long studentId, String fcmToken);
}

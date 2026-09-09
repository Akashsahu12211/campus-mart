package com.campusmart.repository;

import com.campusmart.model.OtpSession;
import com.campusmart.model.RegistrationSession;
import com.campusmart.model.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import jakarta.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface OtpSessionRepository extends JpaRepository<OtpSession, Long> {
    @Query("""
        SELECT o
        FROM OtpSession o
        WHERE o.session = ?1
          AND o.otpType = ?2
          AND (o.isUsed = false OR o.isUsed IS NULL)
        ORDER BY o.createdAt DESC, o.id DESC
    """)
    List<OtpSession> findActiveBySessionAndOtpTypeOrderByLatest(
        RegistrationSession session,
        OtpVerification.OtpType type
    );
    
    @Query("SELECT COUNT(o) FROM OtpSession o WHERE o.session.id = ?1 AND o.otpType = ?2 AND o.createdAt > ?3")
    long countRecentOtps(Long sessionId, OtpVerification.OtpType type, LocalDateTime since);

    @Modifying
    @Transactional
    @Query("""
        UPDATE OtpSession o
        SET o.isUsed = true
        WHERE o.session = ?1
          AND o.otpType = ?2
          AND (o.isUsed = false OR o.isUsed IS NULL)
    """)
    int invalidateActiveOtps(RegistrationSession session, OtpVerification.OtpType type);
}

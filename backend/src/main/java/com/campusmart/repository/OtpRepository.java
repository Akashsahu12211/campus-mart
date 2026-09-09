package com.campusmart.repository;

import com.campusmart.model.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.Optional;

public interface OtpRepository extends JpaRepository<OtpVerification, Long> {

    // Latest unused OTP fetch karo
    @Query("SELECT o FROM OtpVerification o WHERE o.student.id = :userId " +
            "AND o.otpType = :type AND o.isUsed = false " +
            "ORDER BY o.createdAt DESC")
    java.util.List<OtpVerification> findLatestUnused(
            @Param("userId") Long userId,
            @Param("type") OtpVerification.OtpType type);

    // Count recent OTPs (spam check)
    @Query("SELECT COUNT(o) FROM OtpVerification o WHERE o.student.id = :userId " +
            "AND o.otpType = :type AND o.createdAt > :since")
    long countRecentOtps(
            @Param("userId") Long userId,
            @Param("type") OtpVerification.OtpType type,
            @Param("since") LocalDateTime since);

    // Purane OTPs invalidate karo
    @Modifying
    @Transactional
    @Query("UPDATE OtpVerification o SET o.isUsed = true WHERE o.student.id = :userId " +
            "AND o.otpType = :type AND o.isUsed = false")
    void invalidateOldOtps(
            @Param("userId") Long userId,
            @Param("type") OtpVerification.OtpType type);
}
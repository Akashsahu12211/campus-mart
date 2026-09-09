package com.campusmart.repository;

import com.campusmart.model.ApiRateLimitWindow;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ApiRateLimitWindowRepository extends JpaRepository<ApiRateLimitWindow, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<ApiRateLimitWindow> findByRateKey(String rateKey);

    @Modifying
    @Transactional
    void deleteByRateKey(String rateKey);

    @Modifying
    @Transactional
    @Query("DELETE FROM ApiRateLimitWindow window WHERE window.expiresAt < :cutoff")
    int deleteExpiredBefore(@Param("cutoff") LocalDateTime cutoff);

    List<ApiRateLimitWindow> findTop200ByOrderByUpdatedAtDesc();
}

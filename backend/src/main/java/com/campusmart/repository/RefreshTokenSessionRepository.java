package com.campusmart.repository;

import com.campusmart.model.RefreshTokenSession;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface RefreshTokenSessionRepository extends JpaRepository<RefreshTokenSession, Long> {

    Optional<RefreshTokenSession> findByTokenJti(String tokenJti);

    @Query("""
        SELECT token FROM RefreshTokenSession token
        WHERE token.tokenJti = :tokenJti
          AND token.revokedAt IS NULL
          AND token.expiresAt > :now
        """)
    Optional<RefreshTokenSession> findActiveByTokenJti(@Param("tokenJti") String tokenJti,
                                                       @Param("now") LocalDateTime now);

    @Modifying
    @Transactional
    @Query("""
        UPDATE RefreshTokenSession token
           SET token.revokedAt = :now,
               token.replacedByJti = COALESCE(:replacedByJti, token.replacedByJti)
         WHERE token.tokenJti = :tokenJti
           AND token.revokedAt IS NULL
        """)
    int revokeByTokenJti(@Param("tokenJti") String tokenJti,
                         @Param("now") LocalDateTime now,
                         @Param("replacedByJti") String replacedByJti);

    @Modifying
    @Transactional
    @Query("""
        UPDATE RefreshTokenSession token
           SET token.revokedAt = :now
         WHERE token.userId = :userId
           AND token.revokedAt IS NULL
        """)
    int revokeAllActiveByUserId(@Param("userId") Long userId,
                                @Param("now") LocalDateTime now);

    @Modifying
    @Transactional
    @Query("""
        UPDATE RefreshTokenSession token
           SET token.lastUsedAt = :now
         WHERE token.tokenJti = :tokenJti
        """)
    int touch(@Param("tokenJti") String tokenJti,
              @Param("now") LocalDateTime now);

    @Modifying
    @Transactional
    @Query("""
        DELETE FROM RefreshTokenSession token
         WHERE token.expiresAt < :cutoff
            OR (token.revokedAt IS NOT NULL AND token.revokedAt < :cutoff)
        """)
    int deleteExpiredOrRevokedBefore(@Param("cutoff") LocalDateTime cutoff);
}

package com.campusmart.config;

import com.campusmart.model.RefreshTokenSession;
import com.campusmart.repository.RefreshTokenSessionRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * RefreshTokenUtil - Manages refresh token generation and validation
 * Separates short-lived access tokens from long-lived refresh tokens
 * Enables token rotation and revocation strategy
 */
@Component
public class RefreshTokenUtil {

    private static final long TOKEN_CLEANUP_INTERVAL_MS = 15 * 60 * 1000L;

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.refresh.expiry.ms:2592000000}")  // 30 days
    private long refreshExpiryMs;

    private Key key;
    private final RefreshTokenSessionRepository refreshTokenSessionRepository;
    private final Map<String, LocalRefreshTokenData> fallbackTokenStore = new ConcurrentHashMap<>();
    private volatile long lastCleanupAtMs = 0L;

    public RefreshTokenUtil(ObjectProvider<RefreshTokenSessionRepository> refreshTokenSessionRepositoryProvider) {
        this.refreshTokenSessionRepository = refreshTokenSessionRepositoryProvider.getIfAvailable();
    }

    @PostConstruct
    void init() {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
    }

    /**
     * Generate a refresh token that lasts 30 days
     */
    @Transactional
    public String generateRefreshToken(Long userId, String email, Integer sessionVersion) {
        cleanupExpiredTokens();
        long now = System.currentTimeMillis();
        Date expiryDate = new Date(now + refreshExpiryMs);
        int normalizedSessionVersion = sessionVersion == null ? 0 : sessionVersion;
        String jti = UUID.randomUUID().toString();

        String token = Jwts.builder()
                .setId(jti)
                .setSubject(String.valueOf(userId))
                .claim("email", email)
                .claim("type", "REFRESH")
                .claim("sessionVersion", normalizedSessionVersion)
                .setIssuedAt(new Date(now))
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        if (refreshTokenSessionRepository != null) {
            RefreshTokenSession refreshTokenSession = new RefreshTokenSession();
            refreshTokenSession.setTokenJti(jti);
            refreshTokenSession.setUserId(userId);
            refreshTokenSession.setEmail(email);
            refreshTokenSession.setSessionVersion(normalizedSessionVersion);
            refreshTokenSession.setExpiresAt(LocalDateTime.now().plus(refreshExpiryMs, ChronoUnit.MILLIS));
            refreshTokenSessionRepository.save(refreshTokenSession);
        } else {
            fallbackTokenStore.put(
                jti,
                new LocalRefreshTokenData(userId, email, normalizedSessionVersion, LocalDateTime.now().plus(refreshExpiryMs, ChronoUnit.MILLIS))
            );
        }
        return token;
    }

    /**
     * Validate refresh token
     */
    public boolean validateRefreshToken(String token) {
        try {
            cleanupExpiredTokens();
            Claims claims = parseClaims(token);
            if (!"REFRESH".equals(claims.get("type", String.class))) {
                return false;
            }

            String tokenJti = claims.getId();
            if (tokenJti == null || tokenJti.isBlank()) {
                return false;
            }

            if (refreshTokenSessionRepository != null) {
                RefreshTokenSession tokenSession = refreshTokenSessionRepository
                    .findActiveByTokenJti(tokenJti, LocalDateTime.now())
                    .orElse(null);
                if (tokenSession == null) {
                    return false;
                }
                refreshTokenSessionRepository.touch(tokenJti, LocalDateTime.now());
            } else {
                LocalRefreshTokenData tokenData = fallbackTokenStore.get(tokenJti);
                return tokenData != null && tokenData.expiresAt().isAfter(LocalDateTime.now());
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Extract userId from refresh token
     */
    public Long getUserIdFromRefreshToken(String token) {
        try {
            String userId = parseClaims(token).getSubject();
            return Long.parseLong(userId);
        } catch (Exception e) {
            return null;
        }
    }

    public Integer getSessionVersionFromRefreshToken(String token) {
        try {
            Number sessionVersion = parseClaims(token).get("sessionVersion", Number.class);
            return sessionVersion == null ? 0 : sessionVersion.intValue();
        } catch (Exception e) {
            return null;
        }
    }

    @Transactional
    public String rotateRefreshToken(String token) {
        try {
            Claims claims = parseClaims(token);
            String tokenJti = claims.getId();
            if (tokenJti == null || tokenJti.isBlank()) {
                return null;
            }

            if (refreshTokenSessionRepository != null) {
                RefreshTokenSession existingToken = refreshTokenSessionRepository
                    .findActiveByTokenJti(tokenJti, LocalDateTime.now())
                    .orElse(null);
                if (existingToken == null) {
                    return null;
                }

                String replacement = generateRefreshToken(
                    existingToken.getUserId(),
                    existingToken.getEmail(),
                    existingToken.getSessionVersion()
                );
                String replacementJti = parseClaims(replacement).getId();
                refreshTokenSessionRepository.revokeByTokenJti(tokenJti, LocalDateTime.now(), replacementJti);
                return replacement;
            }

            LocalRefreshTokenData tokenData = fallbackTokenStore.get(tokenJti);
            if (tokenData == null || !tokenData.expiresAt().isAfter(LocalDateTime.now())) {
                return null;
            }
            String replacement = generateRefreshToken(
                tokenData.userId(),
                tokenData.email(),
                tokenData.sessionVersion()
            );
            fallbackTokenStore.remove(tokenJti);
            return replacement;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Revoke a refresh token
     */
    @Transactional
    public void revokeRefreshToken(String token) {
        try {
            String tokenJti = parseClaims(token).getId();
            if (tokenJti != null && !tokenJti.isBlank()) {
                if (refreshTokenSessionRepository != null) {
                    refreshTokenSessionRepository.revokeByTokenJti(tokenJti, LocalDateTime.now(), null);
                } else {
                    fallbackTokenStore.remove(tokenJti);
                }
            }
        } catch (Exception ignored) {
            // Ignore invalid token values on best-effort logout/revoke.
        }
    }

    /**
     * Revoke all tokens for a user (logout all devices)
     */
    @Transactional
    public void revokeAllTokensForUser(Long userId) {
        if (refreshTokenSessionRepository != null) {
            refreshTokenSessionRepository.revokeAllActiveByUserId(userId, LocalDateTime.now());
        } else {
            fallbackTokenStore.entrySet().removeIf(entry -> userId.equals(entry.getValue().userId()));
        }
    }

    public long getRefreshExpiryMs() {
        return refreshExpiryMs;
    }

    private Claims parseClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    private void cleanupExpiredTokens() {
        long now = System.currentTimeMillis();
        if (now - lastCleanupAtMs < TOKEN_CLEANUP_INTERVAL_MS) {
            return;
        }
        if (refreshTokenSessionRepository != null) {
            refreshTokenSessionRepository.deleteExpiredOrRevokedBefore(LocalDateTime.now().minusDays(7));
        } else {
            LocalDateTime cutoff = LocalDateTime.now();
            fallbackTokenStore.entrySet().removeIf(entry ->
                entry.getValue() == null || !entry.getValue().expiresAt().isAfter(cutoff)
            );
        }
        lastCleanupAtMs = now;
    }

    private record LocalRefreshTokenData(
        Long userId,
        String email,
        Integer sessionVersion,
        LocalDateTime expiresAt
    ) {}
}

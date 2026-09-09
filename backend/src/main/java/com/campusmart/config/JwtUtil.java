package com.campusmart.config;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtUtil {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.expiry.ms:900000}")
    private long expiryMs;

    private Key key;

    @PostConstruct
    void init() {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
    }

    public String generateToken(Long userId, String email) {
        return generateToken(userId, email, 0);
    }

    public String generateToken(Long userId, String email, Integer sessionVersion) {
        int normalizedSessionVersion = sessionVersion == null ? 0 : sessionVersion;
        return Jwts.builder()
                .setId(UUID.randomUUID().toString())
                .setSubject(String.valueOf(userId))
                .claim("email", email)
                .claim("type", "ACCESS")
                .claim("sessionVersion", normalizedSessionVersion)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + expiryMs))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }

    public Long getUserIdFromToken(String token) {
        Claims claims = parseClaims(token);
        return Long.parseLong(claims.getSubject());
    }

    public String getTokenType(String token) {
        return parseClaims(token).get("type", String.class);
    }

    public Integer getSessionVersionFromToken(String token) {
        Number value = parseClaims(token).get("sessionVersion", Number.class);
        return value == null ? 0 : value.intValue();
    }

    public boolean validateToken(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public long getExpiryMs() {
        return expiryMs;
    }

    private Claims parseClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
    }
}

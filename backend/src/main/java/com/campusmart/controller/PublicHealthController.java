package com.campusmart.controller;

import com.campusmart.config.FirebaseConfig;
import com.campusmart.config.JwtUtil;
import com.campusmart.config.RefreshTokenUtil;
import com.campusmart.service.LegacyItemImageMigrationService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/public")
public class PublicHealthController {

    private final JdbcTemplate jdbcTemplate;
    private final JwtUtil jwtUtil;
    private final RefreshTokenUtil refreshTokenUtil;
    private final FirebaseConfig firebaseConfig;
    private final LegacyItemImageMigrationService legacyItemImageMigrationService;
    private final String environment;
    private final boolean requireSecureTransport;
    private final Instant startedAt = Instant.now();

    public PublicHealthController(
            JdbcTemplate jdbcTemplate,
            JwtUtil jwtUtil,
            RefreshTokenUtil refreshTokenUtil,
            FirebaseConfig firebaseConfig,
            LegacyItemImageMigrationService legacyItemImageMigrationService,
            @Value("${app.environment:development}") String environment,
            @Value("${app.require-secure-transport:false}") boolean requireSecureTransport
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.jwtUtil = jwtUtil;
        this.refreshTokenUtil = refreshTokenUtil;
        this.firebaseConfig = firebaseConfig;
        this.legacyItemImageMigrationService = legacyItemImageMigrationService;
        this.environment = environment;
        this.requireSecureTransport = requireSecureTransport;
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "UP");
        response.put("service", "campus-mart-backend");
        response.put("environment", environment);
        response.put("timestamp", Instant.now().toString());
        response.put("uptimeSeconds", Math.max(0, Instant.now().getEpochSecond() - startedAt.getEpochSecond()));
        response.put("security", Map.of(
            "secureTransportRequired", requireSecureTransport,
            "accessTokenTtlSeconds", jwtUtil.getExpiryMs() / 1000,
            "refreshTokenTtlSeconds", refreshTokenUtil.getRefreshExpiryMs() / 1000
        ));
        return ResponseEntity.ok(response);
    }

    @GetMapping("/ready")
    public ResponseEntity<Map<String, Object>> readiness() {
        Map<String, Object> checks = new LinkedHashMap<>();
        boolean ready = true;

        try {
            Integer dbResult = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            checks.put("database", Integer.valueOf(1).equals(dbResult) ? "UP" : "DOWN");
            ready = ready && Integer.valueOf(1).equals(dbResult);
        } catch (Exception e) {
            checks.put("database", "DOWN");
            checks.put("databaseError", e.getMessage());
            ready = false;
        }

        checks.put("authTokens", "UP");
        checks.put("clock", "UP");

        Map<String, Object> pushCheck = new LinkedHashMap<>();
        pushCheck.put("enabled", firebaseConfig.isPushEnabled());
        pushCheck.put("ready", firebaseConfig.isMessagingReady());
        pushCheck.put("credentialSource", firebaseConfig.getCredentialSource());
        if (!firebaseConfig.getLastError().isBlank()) {
            pushCheck.put("lastError", firebaseConfig.getLastError());
        }
        checks.put("pushNotifications", pushCheck);

        try {
            checks.put("inlineImageMigration", legacyItemImageMigrationService.getInlineImageStats());
        } catch (Exception e) {
            checks.put("inlineImageMigration", Map.of("error", e.getMessage()));
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", ready ? "UP" : "DOWN");
        response.put("environment", environment);
        response.put("timestamp", Instant.now().toString());
        response.put("checks", checks);

        return ResponseEntity.status(ready ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE).body(response);
    }
}

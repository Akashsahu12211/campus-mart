package com.campusmart.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.File;
import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;

@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @Value("${notifications.push.enabled:true}")
    private boolean pushEnabled;

    @Value("${firebase.service-account.path:}")
    private String serviceAccountPath;

    @Value("${firebase.service-account.base64:}")
    private String serviceAccountBase64;

    @Value("${firebase.service-account.json:}")
    private String serviceAccountJson;

    private volatile boolean messagingReady = false;
    private volatile String credentialSource = "disabled";
    private volatile String lastError = "";

    @Bean
    public FirebaseMessaging firebaseMessaging() throws IOException {
        try {
            if (!pushEnabled) {
                log.info("Push notifications disabled via feature flag.");
                credentialSource = "disabled";
                return null;
            }

            InputStream serviceAccount = resolveServiceAccountStream();
            if (serviceAccount == null) {
                credentialSource = "missing";
                lastError = "Firebase service account credentials not configured";
                log.warn("Firebase service account credentials not configured. Push notifications disabled.");
                return null;
            }

            if (FirebaseApp.getApps().isEmpty()) {
                try (InputStream inputStream = serviceAccount) {
                    FirebaseOptions options = new FirebaseOptions.Builder()
                            .setCredentials(GoogleCredentials.fromStream(inputStream))
                            .build();

                    FirebaseApp.initializeApp(options);
                    log.info("Firebase initialized successfully");
                }
            }
            messagingReady = true;
            return FirebaseMessaging.getInstance();
        } catch (IOException e) {
            messagingReady = false;
            lastError = e.getMessage();
            log.warn("Firebase key not found. Notifications disabled.");
            return null;
        } catch (Exception e) {
            messagingReady = false;
            lastError = e.getMessage();
            log.error("Firebase initialization error: {}", e.getMessage());
            return null;
        }
    }

    public boolean isMessagingReady() {
        return messagingReady;
    }

    public boolean isPushEnabled() {
        return pushEnabled;
    }

    public String getCredentialSource() {
        return credentialSource;
    }

    public String getLastError() {
        return lastError;
    }

    private InputStream resolveServiceAccountStream() throws IOException {
        if (serviceAccountJson != null && !serviceAccountJson.isBlank()) {
            credentialSource = "inline-json";
            return new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8));
        }

        if (serviceAccountBase64 != null && !serviceAccountBase64.isBlank()) {
            credentialSource = "base64";
            return new ByteArrayInputStream(Base64.getDecoder().decode(serviceAccountBase64));
        }

        if (serviceAccountPath == null || serviceAccountPath.isBlank()) {
            return null;
        }

        Path resolvedPath = resolveServiceAccountPath(serviceAccountPath.trim());
        if (resolvedPath == null || !Files.isRegularFile(resolvedPath)) {
            lastError = "Firebase service account file not found: " + serviceAccountPath;
            return null;
        }

        credentialSource = "file";
        return new FileInputStream(resolvedPath.toFile());
    }

    private Path resolveServiceAccountPath(String rawPath) {
        Path direct = Paths.get(rawPath);
        if (direct.isAbsolute()) {
            return direct.normalize();
        }

        Path cwd = Paths.get("").toAbsolutePath().normalize();
        Path[] candidates = new Path[] {
            cwd.resolve(rawPath).normalize(),
            cwd.resolve("backend").resolve(rawPath).normalize(),
            cwd.getParent() != null ? cwd.getParent().resolve(rawPath).normalize() : null,
            cwd.getParent() != null ? cwd.getParent().resolve("backend").resolve(rawPath).normalize() : null
        };

        for (Path candidate : candidates) {
            if (candidate != null && Files.isRegularFile(candidate)) {
                return candidate;
            }
        }
        return direct.normalize();
    }
}

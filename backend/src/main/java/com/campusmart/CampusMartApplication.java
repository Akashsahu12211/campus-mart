package com.campusmart;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@SpringBootApplication
@EnableScheduling
@EnableCaching
public class CampusMartApplication {

    public static void main(String[] args) {
        Dotenv dotenv = loadDotenv();

        Map<String, Object> properties = new HashMap<>();
        dotenv.entries().forEach(entry -> {
            if (System.getProperty(entry.getKey()) == null && System.getenv(entry.getKey()) == null) {
                System.setProperty(entry.getKey(), entry.getValue());
                properties.put(entry.getKey(), entry.getValue());
            }
        });

        String appEnvironment = firstNonBlank(
                System.getProperty("APP_ENV"),
                System.getenv("APP_ENV"),
                dotenv.get("APP_ENV"),
                "production"
        );
        String normalizedProfile = normalizeProfile(appEnvironment);
        System.setProperty("app.environment", appEnvironment);
        System.setProperty("spring.profiles.active", firstNonBlank(
                System.getProperty("spring.profiles.active"),
                System.getenv("SPRING_PROFILES_ACTIVE"),
                normalizedProfile
        ));
        properties.put("app.environment", appEnvironment);
        properties.put("spring.profiles.active", System.getProperty("spring.profiles.active"));

        copyIfPresent(dotenv, properties, "MAIL_USERNAME", "spring.mail.username");
        copyIfPresent(dotenv, properties, "MAIL_PASSWORD", "spring.mail.password");
        copyIfPresent(dotenv, properties, "NOTIFICATIONS_FROM_EMAIL", "notifications.from-email");
        copyIfPresent(dotenv, properties, "TWILIO_ACCOUNT_SID", "twilio.account.sid");
        copyIfPresent(dotenv, properties, "TWILIO_AUTH_TOKEN", "twilio.auth.token");
        copyIfPresent(dotenv, properties, "TWILIO_PHONE_NUMBER", "twilio.phone.number");
        copyIfPresent(dotenv, properties, "DB_USERNAME", "spring.datasource.username");
        copyIfPresent(dotenv, properties, "DB_PASSWORD", "spring.datasource.password");
        copyIfPresent(dotenv, properties, "JWT_SECRET", "jwt.secret");
        copyIfPresent(dotenv, properties, "APP_FRONTEND_BASE_URL", "app.frontend.base-url");
        copyIfPresent(dotenv, properties, "APP_CORS_ALLOWED_ORIGINS", "app.cors.allowed-origins");
        copyIfPresent(dotenv, properties, "FIREBASE_SERVICE_ACCOUNT_PATH", "firebase.service-account.path");

        SpringApplication app = new SpringApplication(CampusMartApplication.class);
        app.setDefaultProperties(properties);
        app.run(args);
    }

    private static Dotenv loadDotenv() {
        for (Path directory : candidateConfigDirectories()) {
            Path envPath = directory.resolve(".env");
            if (Files.isRegularFile(envPath)) {
                return Dotenv.configure()
                        .directory(directory.toString())
                        .filename(".env")
                        .ignoreIfMissing()
                        .load();
            }
        }

        return Dotenv.configure()
                .ignoreIfMissing()
                .load();
    }

    private static List<Path> candidateConfigDirectories() {
        LinkedHashSet<Path> directories = new LinkedHashSet<>();
        addIfDirectory(directories, System.getProperty("app.config.dir"));
        addIfDirectory(directories, System.getenv("APP_CONFIG_DIR"));

        Path cwd = Paths.get("").toAbsolutePath().normalize();
        directories.add(cwd);
        directories.add(cwd.resolve("backend"));

        Path parent = cwd.getParent();
        if (parent != null) {
            directories.add(parent);
            directories.add(parent.resolve("backend"));
        }

        return directories.stream()
                .filter(Files::isDirectory)
                .toList();
    }

    private static void addIfDirectory(LinkedHashSet<Path> directories, String rawPath) {
        if (rawPath == null || rawPath.isBlank()) {
            return;
        }

        Path path = Paths.get(rawPath).toAbsolutePath().normalize();
        if (Files.isDirectory(path)) {
            directories.add(path);
        }
    }

    private static String normalizeProfile(String appEnvironment) {
        if (appEnvironment == null || appEnvironment.isBlank()) {
            return "production";
        }

        String value = appEnvironment.trim().toLowerCase();
        return switch (value) {
            case "prod" -> "production";
            case "dev", "local" -> "development";
            default -> value;
        };
    }

    private static String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return "";
    }

    private static void copyIfPresent(Dotenv dotenv, Map<String, Object> properties, String dotenvKey, String springKey) {
        String value = firstNonBlank(
                System.getProperty(springKey),
                System.getenv(dotenvKey),
                dotenv.get(dotenvKey)
        );
        if (value != null && !value.isBlank()) {
            System.setProperty(springKey, value);
            properties.put(springKey, value);
        }
    }
}

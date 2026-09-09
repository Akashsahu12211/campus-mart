package com.campusmart.service;

import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import org.springframework.mail.MailAuthenticationException;
import java.io.OutputStreamWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.charset.StandardCharsets;

@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    @Autowired(required = false)
    private JavaMailSender mailSender;

    @Autowired
    private EmailTemplateService emailTemplateService;

    @Value("${notifications.email.enabled:true}")
    private boolean emailEnabled;

    @Value("${notifications.from-email:noreply@campusmart.com}")
    private String fromEmail;

    @Value("${spring.mail.username:}")
    private String smtpUsername;

    @Value("${spring.mail.password:}")
    private String smtpPassword;

    @PostConstruct
    void logMailRuntimeConfig() {
        String senderType = mailSender == null ? "null" : mailSender.getClass().getSimpleName();
        String configuredUsername = "(unknown)";
        if (mailSender instanceof JavaMailSenderImpl impl) {
            configuredUsername = impl.getUsername();
        }

        log.info(
            "[EMAIL SERVICE] enabled={}, from={}, senderType={}, username={}",
            emailEnabled,
            fromEmail,
            senderType,
            maskEmail(configuredUsername)
        );
    }

    public void sendOtpEmail(String toEmail, String name, String otp) {
        sendHtmlEmail(
                toEmail,
                "Campus Mart - Email Verification OTP",
                emailTemplateService.buildOtpEmail(name, otp, "Email Verification"),
                true
        );
    }

    public void sendWelcomeEmail(String toEmail, String name) {
        sendHtmlEmail(
                toEmail,
                "Welcome to Campus Mart!",
                emailTemplateService.buildWelcomeEmail(name),
                false
        );
    }

    public void sendNotificationEmail(String toEmail, String subject, String html) {
        sendHtmlEmail(toEmail, subject, html, false);
    }

    public void sendEmail(String toEmail, String subject, String message) {
        String html = emailTemplateService.buildGenericMessageEmail(subject, "Campus Mart User", message, null, null);
        sendHtmlEmail(toEmail, subject, html, false);
    }

    private void sendHtmlEmail(String toEmail, String subject, String html, boolean strictMode) {
        if (toEmail == null || toEmail.isBlank()) {
            if (strictMode) {
                throw new RuntimeException("Recipient email is required");
            }
            log.warn("[EMAIL SERVICE] Skipping email because recipient is empty");
            return;
        }

        if (!emailEnabled) {
            String msg = "[EMAIL SERVICE] Email notifications disabled. Skipping subject: " + subject;
            if (strictMode) {
                throw new RuntimeException(msg);
            }
            log.info(msg);
            return;
        }

        if (mailSender == null) {
            String msg = "[EMAIL SERVICE] Mail sender not available. Skipping subject: " + subject;
            if (strictMode) {
                throw new RuntimeException(msg);
            }
            log.warn(msg);
            return;
        }

        try {
            MimeMessage mimeMessage = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(mimeMessage, true, "UTF-8");

            helper.setTo(toEmail);
            helper.setSubject(subject);
            helper.setFrom(fromEmail);
            helper.setText(html, true);

            mailSender.send(mimeMessage);
            log.info("[EMAIL SERVICE] Sent email to {} | Subject: {}", maskEmail(toEmail), subject);
        } catch (Exception e) {
            log.error("[EMAIL SERVICE] Failed to send email to {}: {}", maskEmail(toEmail), e.getMessage());
            if (e instanceof MailAuthenticationException && e.getCause() != null) {
                log.error("[EMAIL SERVICE] Auth cause: {}", e.getCause().getMessage());
            }
            if (e.getCause() != null && e.getCause().getCause() != null) {
                log.error("[EMAIL SERVICE] Root cause: {}", e.getCause().getCause().getMessage());
            }
            if (tryPythonFallback(toEmail, subject, html)) {
                log.info("[EMAIL SERVICE] Python SMTP fallback sent email to {}", maskEmail(toEmail));
                return;
            }
            if (strictMode) {
                throw new RuntimeException("Failed to send email: " + e.getMessage());
            }
        }
    }

    private boolean tryPythonFallback(String toEmail, String subject, String html) {
        if (smtpUsername == null || smtpUsername.isBlank() || smtpPassword == null || smtpPassword.isBlank()) {
            return false;
        }

        try {
            Path scriptPath = resolvePythonFallbackScript();
            if (scriptPath == null) {
                return false;
            }

            ProcessBuilder pb = new ProcessBuilder(
                    "python",
                    scriptPath.toString()
            );
            pb.directory(scriptPath.getParent().getParent().toFile());
            pb.redirectErrorStream(true);

            Process process = pb.start();
            String payload = buildJsonPayload(toEmail, subject, html);
            try (OutputStreamWriter writer = new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8)) {
                writer.write(payload);
            }

            String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
            int exit = process.waitFor();
            if (exit != 0) {
                log.error("[EMAIL SERVICE] Python fallback failed: {}", output);
                return false;
            }
            return true;
        } catch (Exception fallbackError) {
            log.error("[EMAIL SERVICE] Python fallback exception: {}", fallbackError.getMessage());
            return false;
        }
    }

    private Path resolvePythonFallbackScript() {
        Path cwd = Paths.get("").toAbsolutePath().normalize();
        Path[] candidates = new Path[] {
                cwd.resolve("scripts").resolve("send_email.py"),
                cwd.resolve("backend").resolve("scripts").resolve("send_email.py"),
                cwd.getParent() != null ? cwd.getParent().resolve("backend").resolve("scripts").resolve("send_email.py") : null
        };

        for (Path candidate : candidates) {
            if (candidate != null && Files.isRegularFile(candidate)) {
                return candidate;
            }
        }

        return null;
    }

    private String buildJsonPayload(String toEmail, String subject, String html) {
        return "{"
                + "\"username\":\"" + escapeJson(smtpUsername) + "\","
                + "\"password\":\"" + escapeJson(smtpPassword) + "\","
                + "\"from_email\":\"" + escapeJson(fromEmail) + "\","
                + "\"to_email\":\"" + escapeJson(toEmail) + "\","
                + "\"subject\":\"" + escapeJson(subject) + "\","
                + "\"html\":\"" + escapeJson(html) + "\""
                + "}";
    }

    private String escapeJson(String value) {
        if (value == null) {
            return "";
        }
        return value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "(empty)";
        }
        int at = email.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return email.charAt(0) + "***" + email.substring(at);
    }
}

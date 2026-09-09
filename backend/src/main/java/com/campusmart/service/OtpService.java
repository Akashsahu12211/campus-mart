package com.campusmart.service;

import com.campusmart.model.OtpSession;
import com.campusmart.model.OtpVerification;
import com.campusmart.model.RegistrationSession;
import com.campusmart.model.Student;
import com.campusmart.repository.OtpRepository;
import com.campusmart.repository.OtpSessionRepository;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class OtpService {

    private static final Logger log = LoggerFactory.getLogger(OtpService.class);
    private static final int OTP_EXPIRY_MINUTES = 10;
    private static final int MAX_RESEND_COUNT = 3;
    private static final int RESEND_WINDOW_MINUTES = 30;
    private static final int MAX_VERIFY_ATTEMPTS = 3;

    @Autowired private OtpRepository otpRepo;
    @Autowired private OtpSessionRepository otpSessionRepo;
    @Autowired private EmailService emailService;
    @Autowired(required = false) private SmsService smsService;

    @Value("${app.expose-dev-otp:false}")
    private boolean exposeDevOtp;

    private final SecureRandom random = new SecureRandom();

    private String generateOtp() {
        return String.format("%06d", random.nextInt(1000000));
    }

    public void sendEmailOtp(Student student) {
        long recentCount = otpRepo.countRecentOtps(
            student.getId(),
            OtpVerification.OtpType.EMAIL,
            LocalDateTime.now().minusMinutes(RESEND_WINDOW_MINUTES)
        );
        if (recentCount >= MAX_RESEND_COUNT) {
            throw new RuntimeException(
                "Too many OTP requests. Please wait " + RESEND_WINDOW_MINUTES + " minutes."
            );
        }

        otpRepo.invalidateOldOtps(student.getId(), OtpVerification.OtpType.EMAIL);

        String code = generateOtp();
        OtpVerification otp = new OtpVerification();
        otp.setStudent(student);
        otp.setOtpCode(code);
        otp.setOtpType(OtpVerification.OtpType.EMAIL);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        otpRepo.save(otp);

        emailService.sendOtpEmail(student.getEmail(), student.getName(), code);
        logDevOtp("EMAIL", student.getEmail(), code);
    }

    public String sendPhoneOtp(Student student) {
        long recentCount = otpRepo.countRecentOtps(
            student.getId(),
            OtpVerification.OtpType.PHONE,
            LocalDateTime.now().minusMinutes(RESEND_WINDOW_MINUTES)
        );
        if (recentCount >= MAX_RESEND_COUNT) {
            throw new RuntimeException("Too many OTP requests. Try after 30 minutes.");
        }

        otpRepo.invalidateOldOtps(student.getId(), OtpVerification.OtpType.PHONE);

        String code = generateOtp();
        OtpVerification otp = new OtpVerification();
        otp.setStudent(student);
        otp.setOtpCode(code);
        otp.setOtpType(OtpVerification.OtpType.PHONE);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        otpRepo.save(otp);

        logDevOtp("PHONE", student.getPhone(), code);
        return code;
    }

    public boolean verifyOtp(Student student, String code, OtpVerification.OtpType type) {
        List<OtpVerification> otps = otpRepo.findLatestUnused(student.getId(), type);
        if (otps.isEmpty()) {
            throw new RuntimeException("No OTP found. Please request a new one.");
        }

        OtpVerification otp = otps.get(0);
        if (otp.isExpired()) {
            otp.setIsUsed(true);
            otpRepo.save(otp);
            throw new RuntimeException("OTP has expired. Please request a new one.");
        }

        if (otp.isMaxAttemptsReached()) {
            otp.setIsUsed(true);
            otpRepo.save(otp);
            throw new RuntimeException("Too many wrong attempts. Please request a new OTP.");
        }

        if (!otp.getOtpCode().equals(code.trim())) {
            otp.setAttempts(otp.getAttempts() + 1);
            otpRepo.save(otp);
            int remaining = MAX_VERIFY_ATTEMPTS - otp.getAttempts();
            throw new RuntimeException(
                "Wrong OTP. " + (remaining > 0 ? remaining + " attempts remaining." : "No attempts left.")
            );
        }

        otp.setIsUsed(true);
        otpRepo.save(otp);
        return true;
    }

    public String sendEmailOtpForSession(RegistrationSession session) {
        long recentCount = otpSessionRepo.countRecentOtps(
            session.getId(),
            OtpVerification.OtpType.EMAIL,
            LocalDateTime.now().minusMinutes(RESEND_WINDOW_MINUTES)
        );
        if (recentCount >= MAX_RESEND_COUNT) {
            throw new RuntimeException(
                "Too many OTP requests. Please wait " + RESEND_WINDOW_MINUTES + " minutes."
            );
        }

        otpSessionRepo.invalidateActiveOtps(session, OtpVerification.OtpType.EMAIL);

        String code = generateOtp();
        OtpSession otp = new OtpSession();
        otp.setSession(session);
        otp.setOtpCode(code);
        otp.setOtpType(OtpVerification.OtpType.EMAIL);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        otpSessionRepo.save(otp);

        logDevOtp("EMAIL", session.getEmail(), code);
        sendEmailOtpAsync(session.getEmail(), session.getName(), code);
        return code;
    }

    public String sendPhoneOtpForSession(RegistrationSession session) {
        long recentCount = otpSessionRepo.countRecentOtps(
            session.getId(),
            OtpVerification.OtpType.PHONE,
            LocalDateTime.now().minusMinutes(RESEND_WINDOW_MINUTES)
        );
        if (recentCount >= MAX_RESEND_COUNT) {
            throw new RuntimeException("Too many OTP requests. Try after 30 minutes.");
        }

        otpSessionRepo.invalidateActiveOtps(session, OtpVerification.OtpType.PHONE);

        String code = generateOtp();
        OtpSession otp = new OtpSession();
        otp.setSession(session);
        otp.setOtpCode(code);
        otp.setOtpType(OtpVerification.OtpType.PHONE);
        otp.setExpiresAt(LocalDateTime.now().plusMinutes(OTP_EXPIRY_MINUTES));
        otpSessionRepo.save(otp);

        if (smsService != null) {
            boolean sent = smsService.sendOtp(session.getPhone(), code);
            if (!sent) {
                logDevOtp("PHONE-FALLBACK", session.getPhone(), code);
            }
        } else {
            logDevOtp("PHONE", session.getPhone(), code);
        }

        return code;
    }

    public boolean verifyOtpForSession(
        RegistrationSession session,
        String code,
        OtpVerification.OtpType type
    ) {
        List<OtpSession> activeOtpSessions =
            otpSessionRepo.findActiveBySessionAndOtpTypeOrderByLatest(session, type);
        if (activeOtpSessions.isEmpty()) {
            throw new RuntimeException("OTP not found");
        }

        OtpSession otpSession = activeOtpSessions.get(0);
        if (activeOtpSessions.size() > 1) {
            for (int i = 1; i < activeOtpSessions.size(); i++) {
                OtpSession staleOtp = activeOtpSessions.get(i);
                staleOtp.setIsUsed(true);
                otpSessionRepo.save(staleOtp);
            }
        }

        if (otpSession.isExpired()) {
            otpSession.setIsUsed(true);
            otpSessionRepo.save(otpSession);
            throw new RuntimeException("OTP has expired. Please request a new one.");
        }

        if (!otpSession.isValid()) {
            otpSession.setIsUsed(true);
            otpSessionRepo.save(otpSession);
            throw new RuntimeException("Too many wrong attempts. Please request a new OTP.");
        }

        if (!otpSession.getOtpCode().equals(code.trim())) {
            otpSession.setAttempts(otpSession.getAttempts() + 1);
            otpSessionRepo.save(otpSession);
            int remaining = MAX_VERIFY_ATTEMPTS - otpSession.getAttempts();
            throw new RuntimeException(
                "Wrong OTP. " + (remaining > 0 ? remaining + " attempts remaining." : "No attempts left.")
            );
        }

        otpSession.setIsUsed(true);
        otpSessionRepo.save(otpSession);
        return true;
    }

    protected void sendEmailOtpAsync(String email, String name, String code) {
        CompletableFuture.runAsync(() -> {
            try {
                emailService.sendOtpEmail(email, name, code);
                log.info("[EMAIL OTP] Sent to {}", email);
            } catch (Exception e) {
                log.warn("[EMAIL OTP] Failed to send to {}: {}", email, e.getMessage());
            }
        });
    }

    private void logDevOtp(String channel, String recipient, String code) {
        if (!exposeDevOtp) {
            return;
        }
        log.info("[DEV OTP] {} -> {} :: {}", channel, recipient, code);
    }
}

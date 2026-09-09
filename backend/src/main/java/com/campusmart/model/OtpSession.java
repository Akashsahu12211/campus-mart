package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "otp_sessions")
public class OtpSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "session_id", nullable = false)
    private RegistrationSession session;

    @Column(nullable = false)
    private String otpCode;

    @Enumerated(EnumType.STRING)
    private OtpVerification.OtpType otpType;

    private LocalDateTime createdAt = LocalDateTime.now();
    private LocalDateTime expiresAt;
    private Boolean isUsed = false;
    private Integer attempts = 0;

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt) || isUsed;
    }

    public boolean isValid() {
        return !isExpired() && attempts < 3;
    }
}

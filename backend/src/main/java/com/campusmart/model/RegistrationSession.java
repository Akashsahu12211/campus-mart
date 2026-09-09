package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Entity
@Table(name = "registration_sessions")
public class RegistrationSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(unique = true, nullable = false)
    private String phone;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String passwordHash;

    private Boolean emailVerified = false;
    private Boolean phoneVerified = false;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OtpSession> otpSessions;

    private LocalDateTime createdAt = LocalDateTime.now();
    private LocalDateTime expiresAt = LocalDateTime.now().plusHours(1);

    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expiresAt);
    }

    public boolean isBothVerified() {
        return emailVerified && phoneVerified;
    }
}

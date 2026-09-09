package com.campusmart.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "support_requests")
@Data
@NoArgsConstructor
public class SupportRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "student_id")
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student student;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SupportType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SupportStatus status = SupportStatus.OPEN;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String email;

    private String subject;

    private String category;

    @Column(columnDefinition = "TEXT")
    private String message;

    @Column(name = "page_path")
    private String pagePath;

    @Column(name = "app_platform")
    private String appPlatform;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;

    public enum SupportType {
        FEEDBACK, PROBLEM_REPORT, CONTACT
    }

    public enum SupportStatus {
        OPEN, IN_PROGRESS, RESOLVED
    }
}

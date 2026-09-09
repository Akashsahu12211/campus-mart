package com.campusmart.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.util.List;

@Entity
@Table(
    name = "students",
    indexes = {
        @Index(name = "idx_students_hostel", columnList = "hostel"),
        @Index(name = "idx_students_branch", columnList = "branch"),
        @Index(name = "idx_students_lat_lng", columnList = "latitude, longitude"),
        @Index(name = "idx_students_institution_id", columnList = "institution_id")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Student {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    private String password;

    @Column(unique = true, length = 15)
    private String phone;
    private String branch;
    private String hostel;

    @Column(name = "college_id")
    private String collegeId;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "institution_id")
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Institution institution;

    @Enumerated(EnumType.STRING)
    @Column(name = "institution_type")
    private InstitutionType institutionType = InstitutionType.COLLEGE;

    @Column(name = "institution_name")
    private String institutionName;

    @Column(name = "campus_name")
    private String campusName;

    @Column(name = "course_name")
    private String courseName;

    @Column(name = "class_level")
    private String classLevel;

    private String city;

    @Column(name = "state_name")
    private String stateName;

    @Column(name = "country_name")
    private String countryName = "India";

    @Column(name = "profile_pic", columnDefinition = "LONGTEXT", length = 16777215)
    private String profilePic;

    private String bio;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @OneToMany(mappedBy = "seller", cascade = CascadeType.ALL)
    @JsonIgnore
    private List<Item> listedItems;

    @Transient
    @JsonProperty("averageRating")
    private Double averageRating;

    @Transient
    @JsonProperty("totalReviews")
    private Long totalReviews;

    @Column(name = "email_verified")
    private Boolean emailVerified = false;

    @Column(name = "phone_verified")
    private Boolean phoneVerified = false;

    @Column(name = "is_active")
    private Boolean isActive = false;

    @Enumerated(EnumType.STRING)
    @Column(name = "contact_access_tier")
    private ContactAccessTier contactAccessTier = ContactAccessTier.FREE;

    @Column(name = "contact_access_expires_at")
    private LocalDateTime contactAccessExpiresAt;

    @Column(name = "active_subscription_code")
    private String activeSubscriptionCode = "FREE";

    @Column(name = "subscription_activated_at")
    private LocalDateTime subscriptionActivatedAt;

    @Column(name = "available_boost_credits")
    private Integer availableBoostCredits = 0;

    @Column(name = "used_boost_credits")
    private Integer usedBoostCredits = 0;

    @Column(name = "current_commission_percent", precision = 5, scale = 2)
    private BigDecimal currentCommissionPercent = BigDecimal.valueOf(7.00);

    @Column(name = "moderation_strike_count")
    private Integer moderationStrikeCount = 0;

    @Column(name = "device_token", columnDefinition = "TEXT")
    private String deviceToken;

    @Column(name = "device_platform")
    private String devicePlatform;

    @Column(name = "push_notifications_enabled")
    private Boolean pushNotificationsEnabled = true;

    @Column(name = "email_notifications_enabled")
    private Boolean emailNotificationsEnabled = true;

    @Column(name = "show_phone_on_listings")
    private Boolean showPhoneOnListings = true;

    @Column(name = "allow_direct_chat")
    private Boolean allowDirectChat = true;

    @Column(name = "privacy_mode")
    private String privacyMode = "CAMPUS_ONLY";

    @Column(name = "preferred_language")
    private String preferredLanguage = "EN";

    @Column(name = "location_label")
    private String locationLabel;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    @Column(name = "login_attempts")
    private Integer loginAttempts = 0;

    @Column(name = "locked_until")
    private LocalDateTime lockedUntil;

    @Column(name = "auth_session_version")
    private Integer authSessionVersion = 0;

    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;

    @Column(name = "last_login_ip")
    private String lastLoginIp;

    @Column(name = "google_id")
    private String googleId;

    @Column(name = "facebook_id")
    private String facebookId;

    @Enumerated(EnumType.STRING)
    @Column(name = "auth_provider")
    private AuthProvider authProvider = AuthProvider.LOCAL;

    @Enumerated(EnumType.STRING)
    @Column(name = "role")
    private StudentRole role = StudentRole.STUDENT;

    @Column(name = "is_banned")
    private Boolean isBanned = false;

    @Column(name = "ban_reason")
    private String banReason;

    @Column(name = "banned_at")
    private LocalDateTime bannedAt;

    @Transient
    private String maskedPhone;

    @Transient
    private Boolean phoneVisibleToViewer;

    @Transient
    private String contactRevealReason;

    @Transient
    private Boolean identityVerified;

    public enum AuthProvider {
        LOCAL, GOOGLE, FACEBOOK
    }

    public enum ContactAccessTier {
        FREE, PLUS, PREMIUM
    }

    public enum InstitutionType {
        SCHOOL, COLLEGE, UNIVERSITY, COACHING, OTHER
    }

    public enum StudentRole {
        STUDENT, MODERATOR, ADMIN
    }
}

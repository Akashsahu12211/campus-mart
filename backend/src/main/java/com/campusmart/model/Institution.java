package com.campusmart.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "institutions",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_institutions_unique_key", columnNames = "unique_key")
    },
    indexes = {
        @Index(name = "idx_institutions_search", columnList = "institution_type, city, state_name, verified, is_active")
    }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Institution {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "institution_type", nullable = false)
    private Student.InstitutionType institutionType = Student.InstitutionType.COLLEGE;

    @Column(name = "campus_name")
    private String campusName;

    @Column(name = "board_or_university")
    private String boardOrUniversity;

    private String city;

    @Column(name = "state_name")
    private String stateName;

    @Column(name = "country_name")
    private String countryName = "India";

    @Column(name = "unique_key", nullable = false, unique = true, length = 255)
    private String uniqueKey;

    private String website;

    private Boolean verified = false;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @PrePersist
    @PreUpdate
    private void updateUniqueKey() {
        uniqueKey = buildUniqueKey();
    }

    private String buildUniqueKey() {
        return String.join("|",
            normalizeKeyPart(name),
            institutionType != null ? institutionType.name() : "OTHER",
            normalizeKeyPart(campusName),
            normalizeKeyPart(city),
            normalizeKeyPart(stateName),
            normalizeKeyPart(countryName)
        );
    }

    private String normalizeKeyPart(String value) {
        if (value == null || value.isBlank()) {
            return "-";
        }
        return value.trim().toLowerCase();
    }
}

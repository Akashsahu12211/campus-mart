package com.campusmart.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.BatchSize;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(
    name = "items",
    indexes = {
        @Index(name = "idx_items_status_created_at", columnList = "status, created_at"),
        @Index(name = "idx_items_category_status", columnList = "category_id, status"),
        @Index(name = "idx_items_seller_created_at", columnList = "seller_id, created_at"),
        @Index(name = "idx_items_listing_type_status", columnList = "listing_type, status"),
        @Index(name = "idx_items_price", columnList = "price"),
        @Index(name = "idx_items_condition", columnList = "item_condition"),
        @Index(name = "idx_items_boost_expires_at", columnList = "boost_expires_at"),
        @Index(name = "idx_items_created_at", columnList = "created_at")
    }
)
@BatchSize(size = 50)
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Item {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private BigDecimal price;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "item_images", joinColumns = @JoinColumn(name = "item_id"))
    @Column(name = "image_url")
    @BatchSize(size = 50)
    private List<String> imageUrls = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    private ItemStatus status = ItemStatus.AVAILABLE;

    @Column(name = "item_condition")
    @Enumerated(EnumType.STRING)
    private ItemCondition condition = ItemCondition.GOOD;

    @Enumerated(EnumType.STRING)
    @Column(name = "listing_type")
    private ListingType listingType = ListingType.GENERAL;

    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private Boolean negotiable = false;

    @Column(name = "is_donation")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private Boolean donation = false;

    @Column(name = "is_bundle")
    @Getter(AccessLevel.NONE)
    @Setter(AccessLevel.NONE)
    private Boolean bundle = false;

    @Column(name = "bundle_size")
    private Integer bundleSize;

    @Column(name = "book_author")
    private String bookAuthor;

    @Column(name = "book_edition")
    private String bookEdition;

    @Column(name = "academic_subject")
    private String academicSubject;

    @Column(name = "academic_course")
    private String academicCourse;

    @Column(name = "academic_level")
    private String academicLevel;

    @Column(name = "board_or_university")
    private String boardOrUniversity;

    private String publisher;

    private String isbn;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "category_id")
    @BatchSize(size = 50)
    private Category category;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "seller_id")
    @JsonIgnoreProperties({"listedItems", "password"})
    @BatchSize(size = 50)
    private Student seller;

    @Column(name = "reserved_by")
    private Long reservedBy;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "reserved_by", insertable = false, updatable = false)
    @JsonIgnoreProperties({"listedItems", "password", "bio", "hostel", "branch"})
    @BatchSize(size = 50)
    private Student reservedByStudent;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "boost_level")
    private Integer boostLevel = 0;

    @Column(name = "boosted_at")
    private LocalDateTime boostedAt;

    @Column(name = "boost_expires_at")
    private LocalDateTime boostExpiresAt;

    @Transient
    private Boolean boostActive;

    private int viewCount = 0;

    public boolean isNegotiable() {
        return Boolean.TRUE.equals(negotiable);
    }

    public void setNegotiable(Boolean negotiable) {
        this.negotiable = Boolean.TRUE.equals(negotiable);
    }

    public boolean isDonation() {
        return Boolean.TRUE.equals(donation);
    }

    public void setDonation(Boolean donation) {
        this.donation = Boolean.TRUE.equals(donation);
    }

    public boolean isBundle() {
        return Boolean.TRUE.equals(bundle);
    }

    public void setBundle(Boolean bundle) {
        this.bundle = Boolean.TRUE.equals(bundle);
    }

    public enum ItemStatus {
        AVAILABLE, SOLD, RESERVED, EXPIRED, HIDDEN
    }

    public enum ItemCondition {
        NEW, LIKE_NEW, GOOD, FAIR, POOR
    }

    public enum ListingType {
        GENERAL, BOOK, DONATION
    }
}

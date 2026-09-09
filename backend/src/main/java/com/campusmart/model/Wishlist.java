package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "wishlists",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_wishlists_student_item", columnNames = {"student_id", "item_id"})
    },
    indexes = {
        @Index(name = "idx_wishlists_student_created_at", columnList = "student_id, created_at"),
        @Index(name = "idx_wishlists_item", columnList = "item_id")
    }
)
@Data @NoArgsConstructor
public class Wishlist {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "student_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student student;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id", nullable = false)
    @JsonIgnoreProperties({"seller"})
    private Item item;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}

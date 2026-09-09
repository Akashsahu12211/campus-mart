package com.campusmart.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "blocked_users",
    uniqueConstraints = @UniqueConstraint(columnNames = {"blocker_id", "blocked_id"})
)
@Data
@NoArgsConstructor
public class BlockedUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "blocker_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student blocker;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "blocked_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student blocked;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}

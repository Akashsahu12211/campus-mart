package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "chat_rooms",
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uk_chat_rooms_conversation",
            columnNames = {"participant_low_id", "participant_high_id", "conversation_item_key"}
        )
    },
    indexes = {
        @Index(name = "idx_chat_rooms_participants", columnList = "participant_low_id, participant_high_id"),
        @Index(name = "idx_chat_rooms_created_at", columnList = "created_at")
    }
)
@Data
@NoArgsConstructor
public class ChatRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "user1_id", nullable = false)
    @JsonIgnoreProperties({"listedItems","password"})
    private Student user1;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "user2_id", nullable = false)
    @JsonIgnoreProperties({"listedItems","password"})
    private Student user2;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id")
    @JsonIgnoreProperties({"seller","imageUrls","description"})
    private Item item;

    @Column(name = "participant_low_id", nullable = false)
    private Long participantLowId;

    @Column(name = "participant_high_id", nullable = false)
    private Long participantHighId;

    @Column(name = "conversation_item_key", nullable = false)
    private Long conversationItemKey = 0L;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    // Last message (not stored in DB — computed)
    @Transient
    private Message lastMessage;

    @Transient
    private long unreadCount;

    @PrePersist
    @PreUpdate
    private void normalizeConversationIdentity() {
        if (user1 == null || user2 == null || user1.getId() == null || user2.getId() == null) {
            return;
        }

        if (user1.getId() > user2.getId()) {
            Student temp = user1;
            user1 = user2;
            user2 = temp;
        }

        participantLowId = user1.getId();
        participantHighId = user2.getId();
        conversationItemKey = item != null && item.getId() != null ? item.getId() : 0L;
    }
}

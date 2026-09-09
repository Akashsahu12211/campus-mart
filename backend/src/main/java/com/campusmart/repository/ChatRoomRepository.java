package com.campusmart.repository;

import com.campusmart.model.ChatRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface ChatRoomRepository
        extends JpaRepository<ChatRoom, Long> {

    Optional<ChatRoom> findByParticipantLowIdAndParticipantHighIdAndConversationItemKey(
        Long participantLowId,
        Long participantHighId,
        Long conversationItemKey
    );

    // All rooms for a user
    @Query("SELECT r FROM ChatRoom r WHERE " +
           "r.user1.id = :userId OR r.user2.id = :userId " +
           "ORDER BY r.createdAt DESC")
    List<ChatRoom> findAllByUser(@Param("userId") Long userId);
}

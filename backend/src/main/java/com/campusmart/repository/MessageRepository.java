package com.campusmart.repository;

import com.campusmart.model.Message;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Repository
public interface MessageRepository
        extends JpaRepository<Message, Long> {

    // Conversation between 2 users about 1 item
    @EntityGraph(attributePaths = {"sender", "receiver", "item"})
    @Query("SELECT m FROM Message m WHERE " +
           "((m.sender.id = :u1 AND m.receiver.id = :u2) OR " +
           " (m.sender.id = :u2 AND m.receiver.id = :u1)) AND " +
           "(:itemId IS NULL OR m.item.id = :itemId) " +
           "ORDER BY m.createdAt ASC")
    List<Message> findConversation(
        @Param("u1")     Long u1,
        @Param("u2")     Long u2,
        @Param("itemId") Long itemId);

    // All conversations for a user (inbox)
    @EntityGraph(attributePaths = {"sender", "receiver", "item"})
    @Query("SELECT m FROM Message m WHERE " +
           "(m.sender.id = :userId OR m.receiver.id = :userId) " +
           "ORDER BY m.createdAt DESC")
    List<Message> findAllByUser(@Param("userId") Long userId);

    // Unread count
    @Query("SELECT COUNT(m) FROM Message m WHERE " +
           "m.receiver.id = :userId AND m.isRead = false")
    long countUnread(@Param("userId") Long userId);

    // Unread count from specific sender
    @Query("SELECT COUNT(m) FROM Message m WHERE " +
           "m.receiver.id = :receiverId AND " +
           "m.sender.id = :senderId AND " +
           "m.isRead = false")
    long countUnreadFromSender(
        @Param("receiverId") Long receiverId,
        @Param("senderId")   Long senderId);

    // Mark messages as read
    @Modifying
    @Transactional
    @Query("UPDATE Message m SET m.isRead = true WHERE " +
           "m.receiver.id = :receiverId AND " +
           "m.sender.id = :senderId AND " +
           "m.isRead = false")
    int markAsRead(
        @Param("receiverId") Long receiverId,
        @Param("senderId")   Long senderId);

    // Latest messages per conversation (for inbox)
    @Query(value =
        "SELECT m.* FROM messages m " +
        "INNER JOIN (" +
        "  SELECT LEAST(sender_id, receiver_id) as u1, " +
        "         GREATEST(sender_id, receiver_id) as u2, " +
        "         COALESCE(item_id, 0) as item_key, " +
        "         MAX(id) as latest_id " +
        "  FROM messages " +
        "  WHERE sender_id = :userId OR receiver_id = :userId " +
        "  GROUP BY u1, u2, item_key" +
        ") latest ON " +
        "LEAST(m.sender_id, m.receiver_id) = latest.u1 AND " +
        "GREATEST(m.sender_id, m.receiver_id) = latest.u2 AND " +
        "COALESCE(m.item_id, 0) = latest.item_key AND " +
        "m.id = latest.latest_id " +
        "ORDER BY m.created_at DESC",
        nativeQuery = true)
    List<Message> findLatestMessagesForUser(
        @Param("userId") Long userId);
}

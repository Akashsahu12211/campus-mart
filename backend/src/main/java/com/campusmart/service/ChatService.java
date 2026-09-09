package com.campusmart.service;

import com.campusmart.model.ChatMessage;
import com.campusmart.model.ChatRoom;
import com.campusmart.model.Item;
import com.campusmart.model.Message;
import com.campusmart.model.Student;
import com.campusmart.model.ChatMessage.MessageType;
import com.campusmart.repository.ChatRoomRepository;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.MessageRepository;
import com.campusmart.repository.StudentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);
    private static final DateTimeFormatter FMT =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private MessageRepository messageRepo;

    @Autowired
    private ChatRoomRepository roomRepo;

    @Autowired
    private StudentRepository studentRepo;

    @Autowired
    private ItemRepository itemRepo;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private NotificationEventService notificationEventService;

    @Autowired
    private BlockService blockService;

    public Message sendMessage(Long senderId, Long receiverId, Long itemId, String content) {
        log.debug("Processing chat message sender={} receiver={} item={}", senderId, receiverId, itemId);

        if (content == null || content.trim().isEmpty()) {
            throw new RuntimeException("Message cannot be empty");
        }

        Student sender = studentRepo.findById(senderId)
            .orElseThrow(() -> {
                log.warn("Chat sender not found: {}", senderId);
                return new RuntimeException("Sender not found");
            });
        Student receiver = studentRepo.findById(receiverId)
            .orElseThrow(() -> {
                log.warn("Chat receiver not found: {}", receiverId);
                return new RuntimeException("Receiver not found");
            });

        if (Boolean.FALSE.equals(receiver.getAllowDirectChat())) {
            throw new RuntimeException("This user is not accepting direct chat right now");
        }
        if (blockService.isBlockedEitherWay(senderId, receiverId)) {
            throw new RuntimeException("You cannot message this user");
        }

        Message msg = new Message();
        msg.setSender(sender);
        msg.setReceiver(receiver);
        msg.setContent(content.trim());
        msg.setCreatedAt(LocalDateTime.now());

        if (itemId != null) {
            itemRepo.findById(itemId).ifPresent(msg::setItem);
        }

        Message saved = messageRepo.save(msg);
        log.debug("Chat message saved id={}", saved.getId());

        getOrCreateRoom(senderId, receiverId, itemId);

        ChatMessage wsMsg = buildChatMessage(saved);
        messagingTemplate.convertAndSendToUser(receiverId.toString(), "/queue/messages", wsMsg);
        messagingTemplate.convertAndSendToUser(senderId.toString(), "/queue/messages", wsMsg);

        notificationEventService.notifyNewChatMessage(sender, receiver, saved);
        return saved;
    }

    public List<Message> getConversation(Long u1, Long u2, Long itemId) {
        if (blockService.isBlockedEitherWay(u1, u2)) {
            return java.util.Collections.emptyList();
        }
        return messageRepo.findConversation(u1, u2, itemId);
    }

    public List<Map<String, Object>> getInbox(Long userId) {
        List<Message> latestMsgs = messageRepo.findLatestMessagesForUser(userId);
        log.debug("Inbox lookup user={} conversations={}", userId, latestMsgs.size());

        List<Map<String, Object>> inbox = new ArrayList<>();

        for (Message msg : latestMsgs) {
            Map<String, Object> entry = new HashMap<>();
            Student other = msg.getSender().getId().equals(userId)
                ? msg.getReceiver()
                : msg.getSender();

            if (blockService.isBlockedEitherWay(userId, other.getId())) {
                continue;
            }

            entry.put("otherUser", Map.of(
                "id", other.getId(),
                "name", other.getName(),
                "profilePic", other.getProfilePic() != null ? other.getProfilePic() : "",
                "collegeId", other.getCollegeId() != null ? other.getCollegeId() : ""
            ));
            entry.put("lastMessage", Map.of(
                "id", msg.getId(),
                "content", msg.getContent(),
                "timestamp", msg.getCreatedAt().format(FMT),
                "isRead", msg.isRead(),
                "isMine", msg.getSender().getId().equals(userId)
            ));
            entry.put("unreadCount", messageRepo.countUnreadFromSender(userId, other.getId()));

            if (msg.getItem() != null) {
                entry.put("item", Map.of(
                    "id", msg.getItem().getId(),
                    "title", msg.getItem().getTitle(),
                    "price", msg.getItem().getPrice()
                ));
            }

            inbox.add(entry);
        }

        log.debug("Inbox ready user={} visibleConversations={}", userId, inbox.size());
        return inbox;
    }

    public void markAsRead(Long receiverId, Long senderId) {
        messageRepo.markAsRead(receiverId, senderId);

        ChatMessage readNotif = new ChatMessage();
        readNotif.setType(MessageType.READ);
        readNotif.setSenderId(receiverId);
        readNotif.setReceiverId(senderId);

        messagingTemplate.convertAndSendToUser(
            senderId.toString(),
            "/queue/messages",
            readNotif
        );
    }

    public long getUnreadCount(Long userId) {
        return messageRepo.countUnread(userId);
    }

    public void sendTypingIndicator(Long senderId, Long receiverId, String senderName) {
        ChatMessage typing = new ChatMessage();
        typing.setType(MessageType.TYPING);
        typing.setSenderId(senderId);
        typing.setSenderName(senderName);
        typing.setReceiverId(receiverId);

        messagingTemplate.convertAndSendToUser(
            receiverId.toString(),
            "/queue/messages",
            typing
        );
    }

    private ChatMessage buildChatMessage(Message msg) {
        ChatMessage cm = new ChatMessage();
        cm.setType(MessageType.CHAT);
        cm.setMessageId(msg.getId());
        cm.setSenderId(msg.getSender().getId());
        cm.setSenderName(msg.getSender().getName());
        cm.setSenderPic(msg.getSender().getProfilePic());
        cm.setReceiverId(msg.getReceiver().getId());
        cm.setContent(msg.getContent());
        cm.setTimestamp(msg.getCreatedAt().format(FMT));
        cm.setRead(false);
        if (msg.getItem() != null) {
            cm.setItemId(msg.getItem().getId());
        }
        return cm;
    }

    public ChatRoom getOrCreateRoom(Long u1Id, Long u2Id, Long itemId) {
        long participantLowId = Math.min(u1Id, u2Id);
        long participantHighId = Math.max(u1Id, u2Id);
        long conversationItemKey = itemId != null ? itemId : 0L;

        return roomRepo
            .findByParticipantLowIdAndParticipantHighIdAndConversationItemKey(
                participantLowId,
                participantHighId,
                conversationItemKey
            )
            .orElseGet(() -> {
                ChatRoom room = new ChatRoom();
                Student u1 = new Student();
                u1.setId(participantLowId);
                Student u2 = new Student();
                u2.setId(participantHighId);
                room.setUser1(u1);
                room.setUser2(u2);
                if (itemId != null) {
                    Item item = new Item();
                    item.setId(itemId);
                    room.setItem(item);
                }
                return roomRepo.save(room);
            });
    }
}

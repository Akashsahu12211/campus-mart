package com.campusmart.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

// Yeh WebSocket ke through travel karne wala DTO hai
// Database entity nahi hai
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessage {

    public enum MessageType {
        CHAT,    // Normal message
        JOIN,    // User joined
        LEAVE,   // User left
        READ,    // Messages read
        TYPING   // User is typing
    }

    private MessageType type;
    private Long        senderId;
    private String      senderName;
    private String      senderPic;
    private Long        receiverId;
    private Long        itemId;
    private String      content;
    private Long        messageId;   // DB mein save hone ke baad
    private String      timestamp;
    private boolean     isRead;
    private Long        roomId;
}

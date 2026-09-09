package com.campusmart.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class ChatMessageRequest {
    @NotNull(message = "Receiver ID cannot be null")
    @Positive(message = "Receiver ID must be positive")
    private Long receiverId;

    @NotBlank(message = "Message content cannot be blank")
    @Size(min = 1, max = 1000, message = "Message must be between 1 and 1000 characters")
    private String content;
}
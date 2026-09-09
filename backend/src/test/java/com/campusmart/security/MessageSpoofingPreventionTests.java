package com.campusmart.security;

import com.campusmart.controller.ChatController;
import com.campusmart.model.Message;
import com.campusmart.service.ChatService;
import com.campusmart.util.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("Message Spoofing Prevention Tests")
class MessageSpoofingPreventionTests {

    private static final Long USER_1_ID = 1L;
    private static final Long USER_2_ID = 2L;

    @Mock
    private ChatService chatService;

    @Mock
    private RateLimiter rateLimiter;

    private ChatController chatController;

    @BeforeEach
    void setUp() {
        chatController = new ChatController();
        ReflectionTestUtils.setField(chatController, "chatService", chatService);
        ReflectionTestUtils.setField(chatController, "rateLimiter", rateLimiter);
    }

    @Test
    @DisplayName("Unauthenticated HTTP chat requests are rejected")
    void testMessageRequiresAuthentication() {
        ResponseEntity<?> response = chatController.sendMessage(
            Map.of("senderId", USER_1_ID, "receiverId", USER_2_ID, "content", "Hello"),
            new MockHttpServletRequest()
        );

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        assertThat(response.getBody()).isEqualTo(Map.of("error", "Unauthorized"));
        verify(chatService, never()).sendMessage(USER_1_ID, USER_2_ID, null, "Hello");
    }

    @Test
    @DisplayName("User cannot spoof sender identity in HTTP chat API")
    void testUserCannotSpoofSenderId() {
        MockHttpServletRequest request = authenticatedRequest(USER_1_ID);

        ResponseEntity<?> response = chatController.sendMessage(
            Map.of("senderId", 999L, "receiverId", USER_2_ID, "content", "Impersonating another user"),
            request
        );

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        assertThat(response.getBody()).isEqualTo(Map.of("error", "Unauthorized"));
        verify(chatService, never()).sendMessage(999L, USER_2_ID, null, "Impersonating another user");
    }

    @Test
    @DisplayName("Authenticated sender identity is used for message delivery")
    void testAuthenticatedUserCanSendMessage() {
        Message savedMessage = new Message();
        savedMessage.setId(55L);
        when(chatService.sendMessage(eq(USER_1_ID), eq(USER_2_ID), eq(null), eq("Hello"))).thenReturn(savedMessage);

        ResponseEntity<?> response = chatController.sendMessage(
            Map.of("senderId", USER_1_ID, "receiverId", USER_2_ID, "content", "Hello"),
            authenticatedRequest(USER_1_ID)
        );

        assertThat(response.getStatusCode().value()).isEqualTo(200);
        assertThat(response.getBody()).isSameAs(savedMessage);

        ArgumentCaptor<Long> senderCaptor = ArgumentCaptor.forClass(Long.class);
        verify(chatService).sendMessage(senderCaptor.capture(), eq(USER_2_ID), eq(null), eq("Hello"));
        assertThat(senderCaptor.getValue()).isEqualTo(USER_1_ID);
    }

    private MockHttpServletRequest authenticatedRequest(Long userId) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute("userId", userId);
        return request;
    }
}

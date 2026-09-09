package com.campusmart.config;

import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class WebSocketAuthChannelInterceptor implements ChannelInterceptor {

    private final JwtUtil jwtUtil;
    private final StudentRepository studentRepository;

    public WebSocketAuthChannelInterceptor(JwtUtil jwtUtil, StudentRepository studentRepository) {
        this.jwtUtil = jwtUtil;
        this.studentRepository = studentRepository;
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null || accessor.getCommand() == null) {
            return message;
        }

        StompCommand command = accessor.getCommand();
        if (StompCommand.CONNECT.equals(command)) {
            String authHeader = firstHeader(accessor, "Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                throw new AccessDeniedException("Missing WebSocket authorization token");
            }

            String token = authHeader.substring(7);
            if (!jwtUtil.validateToken(token) || !"ACCESS".equals(jwtUtil.getTokenType(token))) {
                throw new AccessDeniedException("Invalid WebSocket access token");
            }

            Long userId = jwtUtil.getUserIdFromToken(token);
            Student student = studentRepository.findById(userId)
                    .orElseThrow(() -> new AccessDeniedException("User not found"));
            int currentVersion = student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion();
            if (jwtUtil.getSessionVersionFromToken(token) != currentVersion) {
                throw new AccessDeniedException("WebSocket session expired");
            }
            if (!Boolean.TRUE.equals(student.getIsActive()) || Boolean.TRUE.equals(student.getIsBanned())) {
                throw new AccessDeniedException("Account not eligible for WebSocket access");
            }

            AuthenticatedStudent authenticatedStudent = AuthenticatedStudent.from(student);
            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(
                            authenticatedStudent,
                            token,
                            authenticatedStudent.getAuthorities()
                    );
            accessor.setUser(authentication);
            return message;
        }

        if ((StompCommand.SEND.equals(command) || StompCommand.SUBSCRIBE.equals(command))
                && accessor.getUser() == null) {
            throw new AccessDeniedException("Unauthorized WebSocket session");
        }

        return message;
    }

    private String firstHeader(StompHeaderAccessor accessor, String headerName) {
        List<String> values = accessor.getNativeHeader(headerName);
        if (values == null || values.isEmpty()) {
            return null;
        }
        return values.get(0);
    }
}

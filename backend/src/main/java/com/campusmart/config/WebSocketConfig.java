package com.campusmart.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.StompWebSocketEndpointRegistration;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.Arrays;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final WebSocketAuthChannelInterceptor webSocketAuthChannelInterceptor;

    @Value("${app.websocket.allowed-origins:}")
    private String allowedOrigins;

    @Value("${app.websocket.broker-relay-host:}")
    private String brokerRelayHost;

    @Value("${app.websocket.broker-relay-port:61613}")
    private int brokerRelayPort;

    @Value("${app.websocket.broker-relay-login:}")
    private String brokerRelayLogin;

    @Value("${app.websocket.broker-relay-passcode:}")
    private String brokerRelayPasscode;

    @Value("${app.websocket.broker-relay-virtual-host:}")
    private String brokerRelayVirtualHost;

    public WebSocketConfig(WebSocketAuthChannelInterceptor webSocketAuthChannelInterceptor) {
        this.webSocketAuthChannelInterceptor = webSocketAuthChannelInterceptor;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        if (brokerRelayHost != null && !brokerRelayHost.isBlank()) {
            registry.enableStompBrokerRelay("/topic", "/queue")
                .setRelayHost(brokerRelayHost.trim())
                .setRelayPort(brokerRelayPort)
                .setClientLogin(brokerRelayLogin)
                .setClientPasscode(brokerRelayPasscode)
                .setSystemLogin(brokerRelayLogin)
                .setSystemPasscode(brokerRelayPasscode)
                .setVirtualHost(brokerRelayVirtualHost == null ? "" : brokerRelayVirtualHost.trim());
        } else {
            registry.enableSimpleBroker("/topic", "/queue");
        }
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(webSocketAuthChannelInterceptor);
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        String[] origins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toArray(String[]::new);

        StompWebSocketEndpointRegistration endpoint = registry.addEndpoint("/ws");
        if (origins.length > 0) {
            endpoint.setAllowedOrigins(origins);
        }
        endpoint.withSockJS();
    }
}

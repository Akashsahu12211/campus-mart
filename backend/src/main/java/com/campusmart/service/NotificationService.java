package com.campusmart.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    @Autowired(required = false)
    private FirebaseMessaging firebaseMessaging;

    @Value("${notifications.push.enabled:true}")
    private boolean pushEnabled;

    public void sendNotification(String deviceToken, String title, String body, Map<String, String> data) {
        if (!pushEnabled) {
            log.info("Push notifications disabled. Skipping push delivery for notification '{}'", title);
            return;
        }

        if (firebaseMessaging == null) {
            log.warn("Firebase not initialized, notification not sent");
            return;
        }

        if (deviceToken == null || deviceToken.isBlank()) {
            log.debug("Device token is empty, notification not sent");
            return;
        }

        try {
            Message.Builder messageBuilder = Message.builder()
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .setToken(deviceToken);

            if (data != null && !data.isEmpty()) {
                messageBuilder.putAllData(data);
            }

            String response = firebaseMessaging.send(messageBuilder.build());
            log.debug("Notification sent successfully. Response={}", response);
        } catch (Exception e) {
            log.error("Failed to send notification: {}", e.getMessage());
        }
    }

    public void sendNotification(String deviceToken, String title, String body) {
        sendNotification(deviceToken, title, body, null);
    }

    public void sendNotificationToMultiple(java.util.List<String> deviceTokens, String title, String body) {
        if (deviceTokens == null || deviceTokens.isEmpty()) {
            log.debug("No device tokens provided for multicast notification");
            return;
        }

        deviceTokens.forEach(token -> sendNotification(token, title, body));
    }

    public void sendNotificationToMultiple(java.util.Collection<String> deviceTokens, String title, String body, Map<String, String> data) {
        if (deviceTokens == null || deviceTokens.isEmpty()) {
            log.debug("No device tokens provided for multicast notification");
            return;
        }

        deviceTokens.forEach(token -> sendNotification(token, title, body, data));
    }

    public void sendMessageNotification(String deviceToken, String senderName, String messagePreview) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "NEW_MESSAGE");
        data.put("sender", senderName);

        sendNotification(
                deviceToken,
                "New Message",
                senderName + ": " + truncate(messagePreview, 60),
                data
        );
    }

    public void sendOfferNotification(String deviceToken, String buyerName, String itemTitle, String price) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "NEW_OFFER");
        data.put("buyer", buyerName);
        data.put("item", itemTitle);

        sendNotification(
                deviceToken,
                "New Offer Received",
                buyerName + " offered " + price,
                data
        );
    }

    public void sendOfferResponseNotification(String deviceToken, String status, String itemTitle) {
        Map<String, String> data = new HashMap<>();
        data.put("type", "OFFER_" + status.toUpperCase());
        data.put("item", itemTitle);

        sendNotification(
                deviceToken,
                "Offer Updated",
                "Your offer was " + status,
                data
        );
    }

    private String truncate(String value, int maxLength) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String trimmed = value.trim();
        return trimmed.length() > maxLength ? trimmed.substring(0, maxLength - 3) + "..." : trimmed;
    }
}

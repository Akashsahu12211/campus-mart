package com.campusmart.service;

import com.campusmart.model.Item;
import com.campusmart.model.Message;
import com.campusmart.model.Offer;
import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class NotificationEventService {

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private EmailService emailService;

    @Autowired(required = false)
    private NotificationService notificationService;

    @Autowired
    private EmailTemplateService emailTemplateService;

    @Autowired
    private NotificationTokenService notificationTokenService;

    @Autowired
    private NotificationCenterService notificationCenterService;

    @Value("${notifications.email.enabled:true}")
    private boolean emailEnabled;

    @Value("${notifications.push.enabled:true}")
    private boolean pushEnabled;

    @Value("${notifications.new-item.email-broadcast.enabled:false}")
    private boolean newItemEmailBroadcastEnabled;

    @Value("${notifications.new-item.batch-size:200}")
    private int newItemBatchSize;

    @Value("${notifications.new-item.max-recipients:2000}")
    private int newItemMaxRecipients;

    public void notifyNewItemAdded(Item item) {
        if (item == null || item.getSeller() == null || item.getSeller().getId() == null) {
            return;
        }

        int processedRecipients = 0;
        int pageNumber = 0;
        Page<Student> recipientPage;

        do {
            recipientPage = studentRepository.findByIdNotAndIsActiveTrueAndIsBannedFalse(
                item.getSeller().getId(),
                PageRequest.of(pageNumber, Math.max(1, newItemBatchSize))
            );

            for (Student recipient : recipientPage.getContent()) {
                if (recipient == null || sameUser(recipient, item.getSeller())) {
                    continue;
                }
                if (newItemMaxRecipients > 0 && processedRecipients >= newItemMaxRecipients) {
                    return;
                }

                deliverNewItemNotification(item, recipient);
                processedRecipients++;
            }

            pageNumber++;
        } while (recipientPage.hasNext());
    }

    private void deliverNewItemNotification(Item item, Student recipient) {
        if (emailEnabled && newItemEmailBroadcastEnabled && hasText(recipient.getEmail())) {
            emailService.sendNotificationEmail(
                    recipient.getEmail(),
                    "New Item Added on Campus Mart",
                    emailTemplateService.buildNewItemAddedEmail(recipient.getName(), item)
            );
        }

        createInboxNotification(recipient, "New Item Added", item.getTitle() + " - " + price(item.getPrice()), "NEW_ITEM", "/item/" + item.getId());

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("NEW_ITEM", "/item/" + item.getId());
            data.put("itemId", String.valueOf(item.getId()));
            sendPushToStudent(
                    recipient,
                    "New Item Added",
                    item.getTitle() + " - " + price(item.getPrice()),
                    data
            );
        }
    }

    public void notifyNewChatMessage(Student sender, Student receiver, Message message) {
        if (sender == null || receiver == null || sameUser(sender, receiver) || message == null) {
            return;
        }

        String messagePreview = preview(message.getContent(), 120);
        if (emailEnabled && hasText(receiver.getEmail())) {
            emailService.sendNotificationEmail(
                    receiver.getEmail(),
                    "New Message on Campus Mart",
                    emailTemplateService.buildChatMessageEmail(receiver.getName(), sender.getName(), messagePreview)
            );
        }

        createInboxNotification(receiver, "New Message", sender.getName() + ": " + preview(messagePreview, 80), "NEW_MESSAGE", "/chat");

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("NEW_MESSAGE", "/chat");
            data.put("senderId", String.valueOf(sender.getId()));
            data.put("receiverId", String.valueOf(receiver.getId()));
            if (message.getItem() != null && message.getItem().getId() != null) {
                data.put("itemId", String.valueOf(message.getItem().getId()));
            }
            sendPushToStudent(
                    receiver,
                    "New Message",
                    sender.getName() + ": " + preview(messagePreview, 80),
                    data
            );
        }
    }

    public void notifyNewOffer(Offer offer) {
        if (offer == null || offer.getItem() == null || offer.getItem().getSeller() == null || offer.getBuyer() == null) {
            return;
        }

        Student seller = offer.getItem().getSeller();
        if (sameUser(seller, offer.getBuyer())) {
            return;
        }

        if (emailEnabled && hasText(seller.getEmail())) {
            emailService.sendNotificationEmail(
                    seller.getEmail(),
                    "New Offer Received",
                    emailTemplateService.buildOfferReceivedEmail(seller.getName(), offer)
            );
        }

        createInboxNotification(seller, "New Offer Received", offer.getBuyer().getName() + " offered " + price(offer.getOfferedPrice()), "NEW_OFFER", "/my-items");

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("NEW_OFFER", "/my-items");
            data.put("offerId", String.valueOf(offer.getId()));
            data.put("itemId", String.valueOf(offer.getItem().getId()));
            sendPushToStudent(
                    seller,
                    "New Offer Received",
                    offer.getBuyer().getName() + " offered " + price(offer.getOfferedPrice()),
                    data
            );
        }
    }

    public void notifyOfferStatusUpdated(Offer offer) {
        if (offer == null || offer.getBuyer() == null || offer.getStatus() == null) {
            return;
        }

        Student buyer = offer.getBuyer();
        if (emailEnabled && hasText(buyer.getEmail())) {
            emailService.sendNotificationEmail(
                    buyer.getEmail(),
                    "Your Offer Status Updated",
                    emailTemplateService.buildOfferStatusEmail(buyer.getName(), offer)
            );
        }

        createInboxNotification(buyer, "Offer Updated", "Your offer was " + offer.getStatus().name().toLowerCase(), "OFFER_STATUS", "/item/" + offer.getItem().getId());

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("OFFER_STATUS", "/item/" + offer.getItem().getId());
            data.put("offerId", String.valueOf(offer.getId()));
            data.put("status", offer.getStatus().name());
            sendPushToStudent(
                    buyer,
                    "Offer Updated",
                    "Your offer was " + offer.getStatus().name().toLowerCase(),
                    data
            );
        }
    }

    public void notifyItemReserved(Item item, Student buyer) {
        if (item == null || item.getSeller() == null || buyer == null || sameUser(item.getSeller(), buyer)) {
            return;
        }

        Student seller = item.getSeller();
        if (emailEnabled && hasText(seller.getEmail())) {
            emailService.sendNotificationEmail(
                    seller.getEmail(),
                    "Your Item Has Been Reserved",
                    emailTemplateService.buildItemReservedEmail(seller.getName(), item, buyer.getName())
            );
        }

        createInboxNotification(seller, "Item Reserved", buyer.getName() + " reserved your item.", "ITEM_RESERVED", "/my-items");

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("ITEM_RESERVED", "/my-items");
            data.put("itemId", String.valueOf(item.getId()));
            data.put("buyerId", String.valueOf(buyer.getId()));
            sendPushToStudent(
                    seller,
                    "Item Reserved",
                    buyer.getName() + " reserved your item.",
                    data
            );
        }
    }

    public void notifyItemExpiryReminder(Item item) {
        if (item == null || item.getSeller() == null) {
            return;
        }

        Student seller = item.getSeller();
        if (emailEnabled && hasText(seller.getEmail())) {
            emailService.sendNotificationEmail(
                    seller.getEmail(),
                    "Your Item Will Expire Soon",
                    emailTemplateService.buildItemExpiryReminderEmail(seller.getName(), item)
            );
        }

        createInboxNotification(seller, "Item Expiry Reminder", item.getTitle() + " will expire soon.", "ITEM_EXPIRY_REMINDER", "/my-items");

        if (pushEnabled && notificationService != null) {
            Map<String, String> data = baseData("ITEM_EXPIRY_REMINDER", "/my-items");
            data.put("itemId", String.valueOf(item.getId()));
            sendPushToStudent(
                    seller,
                    "Item Expiry Reminder",
                    item.getTitle() + " will expire soon.",
                    data
            );
        }
    }

    private Map<String, String> baseData(String type, String clickAction) {
        Map<String, String> data = new HashMap<>();
        data.put("type", type);
        if (clickAction != null && !clickAction.isBlank()) {
            data.put("clickAction", clickAction);
            data.put("click_action", clickAction);
        }
        return data;
    }

    private boolean sameUser(Student one, Student two) {
        return one != null && two != null && one.getId() != null && one.getId().equals(two.getId());
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private void createInboxNotification(Student student, String title, String body, String type, String clickAction) {
        if (student == null || student.getId() == null) {
            return;
        }
        notificationCenterService.createNotification(student.getId(), title, body, type, clickAction);
    }

    private void sendPushToStudent(Student student, String title, String body, Map<String, String> data) {
        if (student == null || student.getId() == null || notificationService == null) {
            return;
        }

        var tokens = notificationTokenService.getTokensForStudent(student.getId(), student.getDeviceToken());
        if (tokens.isEmpty()) {
            return;
        }

        notificationService.sendNotificationToMultiple(tokens, title, body, data);
    }

    private String preview(String value, int maxLength) {
        if (value == null || value.isBlank()) {
            return "Open Campus Mart to view the full update.";
        }
        String trimmed = value.trim().replaceAll("\\s+", " ");
        return trimmed.length() > maxLength ? trimmed.substring(0, maxLength - 3) + "..." : trimmed;
    }

    private String price(BigDecimal value) {
        return value != null ? "₹" + value.stripTrailingZeros().toPlainString() : "₹0";
    }

    private String price(Double value) {
        return value != null ? "₹" + String.format("%.2f", value) : "₹0";
    }
}

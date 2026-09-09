package com.campusmart.service;

import com.campusmart.model.Item;
import com.campusmart.model.NotificationEntry;
import com.campusmart.model.PaymentOrder;
import com.campusmart.model.SupportRequest;
import com.campusmart.model.Transaction;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.NotificationEntryRepository;
import com.campusmart.repository.PaymentOrderRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.repository.SupportRequestRepository;
import com.campusmart.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class ActivityService {

    @Autowired private StudentRepository studentRepository;
    @Autowired private NotificationEntryRepository notificationEntryRepository;
    @Autowired private ItemRepository itemRepository;
    @Autowired private PaymentOrderRepository paymentOrderRepository;
    @Autowired private SupportRequestRepository supportRequestRepository;
    @Autowired private TransactionRepository transactionRepository;

    public List<Map<String, Object>> getActivityHistory(Long userId) {
        studentRepository.findById(userId)
            .orElseThrow(() -> new RuntimeException("Student not found"));

        List<Map<String, Object>> timeline = new ArrayList<>();

        notificationEntryRepository
            .findTop50ByStudentIdOrderByCreatedAtDesc(userId)
            .forEach(notification -> timeline.add(fromNotification(notification)));

        itemRepository.findBySellerIdOrderByCreatedAtDesc(userId).stream()
            .limit(20)
            .forEach(item -> timeline.add(fromItem(item)));

        paymentOrderRepository.findByBuyerIdOrderByCreatedAtDesc(userId).stream()
            .limit(20)
            .forEach(order -> timeline.add(fromOrder(order, "BUYER_ORDER")));

        paymentOrderRepository.findBySellerIdOrderByCreatedAtDesc(userId).stream()
            .limit(20)
            .forEach(order -> timeline.add(fromOrder(order, "SELLER_ORDER")));

        supportRequestRepository.findByStudentIdOrderByCreatedAtDesc(userId).stream()
            .limit(10)
            .forEach(request -> timeline.add(fromSupport(request)));

        transactionRepository.findByBuyerIdOrderByCreatedAtDesc(userId).stream()
            .limit(10)
            .forEach(transaction -> timeline.add(fromTransaction(transaction, "PURCHASE")));

        transactionRepository.findBySellerIdOrderByCreatedAtDesc(userId).stream()
            .limit(10)
            .forEach(transaction -> timeline.add(fromTransaction(transaction, "SALE")));

        return timeline.stream()
            .sorted(Comparator.comparing(
                activity -> (LocalDateTime) activity.get("createdAt"),
                Comparator.nullsLast(Comparator.reverseOrder())
            ))
            .limit(60)
            .collect(Collectors.toList());
    }

    private Map<String, Object> fromNotification(NotificationEntry entry) {
        Map<String, Object> activity = baseActivity(
            "NOTIFICATION",
            entry.getId(),
            entry.getCreatedAt(),
            entry.getTitle(),
            entry.getBody()
        );
        activity.put("status", entry.isRead() ? "READ" : "UNREAD");
        activity.put("meta", Map.of(
            "notificationType", safeString(entry.getType()),
            "clickAction", safeString(entry.getClickAction())
        ));
        return activity;
    }

    private Map<String, Object> fromItem(Item item) {
        Map<String, Object> activity = baseActivity(
            "LISTING",
            item.getId(),
            item.getCreatedAt(),
            "Listing updated",
            item.getTitle()
        );
        activity.put("status", item.getStatus() != null ? item.getStatus().name() : "UNKNOWN");
        activity.put("meta", Map.of(
            "price", item.getPrice() != null ? item.getPrice() : BigDecimal.ZERO,
            "views", item.getViewCount(),
            "category", item.getCategory() != null ? safeString(item.getCategory().getName()) : ""
        ));
        return activity;
    }

    private Map<String, Object> fromOrder(PaymentOrder order, String type) {
        String title = "BUYER_ORDER".equals(type) ? "Payment update" : "Seller payout update";
        String body = order.getItem() != null ? order.getItem().getTitle() : "Marketplace order";
        Map<String, Object> activity = baseActivity(
            type,
            order.getId(),
            order.getUpdatedAt() != null ? order.getUpdatedAt() : order.getCreatedAt(),
            title,
            body
        );
        activity.put("status", order.getStatus() != null ? order.getStatus().name() : "UNKNOWN");
        activity.put("meta", Map.of(
            "amount", order.getAmount() != null ? order.getAmount() : BigDecimal.ZERO,
            "itemId", order.getItem() != null ? order.getItem().getId() : null,
            "itemTitle", order.getItem() != null ? safeString(order.getItem().getTitle()) : ""
        ));
        return activity;
    }

    private Map<String, Object> fromSupport(SupportRequest request) {
        Map<String, Object> activity = baseActivity(
            "SUPPORT",
            request.getId(),
            request.getCreatedAt(),
            "Support request",
            safeString(request.getSubject()).isBlank() ? safeString(request.getCategory()) : safeString(request.getSubject())
        );
        activity.put("status", request.getStatus() != null ? request.getStatus().name() : "OPEN");
        activity.put("meta", Map.of(
            "supportType", request.getType() != null ? request.getType().name() : "",
            "pagePath", safeString(request.getPagePath()),
            "platform", safeString(request.getAppPlatform())
        ));
        return activity;
    }

    private Map<String, Object> fromTransaction(Transaction transaction, String type) {
        Map<String, Object> activity = baseActivity(
            type,
            transaction.getId(),
            transaction.getCreatedAt(),
            "PURCHASE".equals(type) ? "Purchase recorded" : "Sale recorded",
            transaction.getItem() != null ? safeString(transaction.getItem().getTitle()) : "Marketplace transaction"
        );
        activity.put("status", transaction.getStatus() != null ? transaction.getStatus().name() : "COMPLETED");
        activity.put("meta", Map.of(
            "amount", transaction.getAmount() != null ? transaction.getAmount() : BigDecimal.ZERO,
            "itemId", transaction.getItem() != null ? transaction.getItem().getId() : null
        ));
        return activity;
    }

    private Map<String, Object> baseActivity(
        String type,
        Long id,
        LocalDateTime createdAt,
        String title,
        String description
    ) {
        Map<String, Object> activity = new LinkedHashMap<>();
        activity.put("type", type);
        activity.put("id", id);
        activity.put("createdAt", createdAt);
        activity.put("title", safeString(title));
        activity.put("description", safeString(description));
        return activity;
    }

    private String safeString(String value) {
        return value == null ? "" : value;
    }
}

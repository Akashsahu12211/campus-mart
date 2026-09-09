package com.campusmart.service;

import com.campusmart.model.CommissionLedgerEntry.EntryType;
import com.campusmart.model.EscrowEvent;
import com.campusmart.model.EscrowEvent.EventType;
import com.campusmart.model.Item;
import com.campusmart.model.Offer;
import com.campusmart.model.PaymentOrder;
import com.campusmart.model.PaymentOrder.PaymentStatus;
import com.campusmart.model.Student;
import com.campusmart.repository.EscrowEventRepository;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.OfferRepository;
import com.campusmart.repository.PaymentOrderRepository;
import com.campusmart.repository.StudentRepository;
import com.razorpay.Order;
import com.razorpay.Payment;
import com.razorpay.RazorpayClient;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
public class PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentService.class);
    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final List<String> SUCCESSFUL_PAYMENT_STATUSES = List.of("captured", "authorized");

    @Value("${razorpay.key.id:}")
    private String razorpayKeyId;

    @Value("${razorpay.key.secret:}")
    private String razorpayKeySecret;

    @Value("${razorpay.webhook.secret:}")
    private String razorpayWebhookSecret;

    @Value("${razorpay.escrow.auto.release.hours:48}")
    private int escrowAutoReleaseHours;

    @Autowired private PaymentOrderRepository paymentRepo;
    @Autowired private EscrowEventRepository escrowEventRepo;
    @Autowired private ItemRepository itemRepo;
    @Autowired private StudentRepository studentRepo;
    @Autowired private OfferRepository offerRepo;
    @Autowired private MonetizationService monetizationService;

    @Transactional
    public Map<String, Object> createOrder(
            Long buyerId,
            Long itemId,
            BigDecimal quotedAmount,
            String notes
    ) throws Exception {
        Item item = itemRepo.findById(itemId)
                .orElseThrow(() -> new RuntimeException("Item not found"));
        validateItemPurchasable(item, buyerId);

        Student buyer = studentRepo.findById(buyerId)
                .orElseThrow(() -> new RuntimeException("Buyer not found"));
        requireGatewayConfigured();

        OrderQuote quote = resolveOrderQuote(item, buyerId, quotedAmount, notes);
        BigDecimal amount = quote.amount();
        String effectiveNotes = quote.notes();

        RazorpayClient client = buildRazorpayClient();
        JSONObject orderReq = new JSONObject();
        orderReq.put("amount", toPaise(amount));
        orderReq.put("currency", "INR");
        orderReq.put("receipt", buildReceipt(itemId, buyerId));
        orderReq.put("notes", new JSONObject()
                .put("itemId", itemId.toString())
                .put("itemTitle", item.getTitle())
                .put("buyerId", buyerId.toString())
                .put("sellerId", item.getSeller().getId().toString())
                .put("pricingSource", quote.pricingSource())
                .put("notes", effectiveNotes != null ? effectiveNotes : ""));

        Order razorpayOrder = client.orders.create(orderReq);

        PaymentOrder paymentOrder = new PaymentOrder();
        paymentOrder.setRazorpayOrderId(razorpayOrder.get("id").toString());
        paymentOrder.setAmount(amount);
        paymentOrder.setBuyer(buyer);
        paymentOrder.setSeller(item.getSeller());
        paymentOrder.setItem(item);
        paymentOrder.setNotes(effectiveNotes);
        paymentOrder.setStatus(PaymentStatus.CREATED);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        monetizationService.applyFeeBreakdown(paymentOrder, item.getSeller());
        paymentRepo.save(paymentOrder);

        logEvent(
                paymentOrder,
                EventType.ORDER_CREATED,
                buyerId,
                "Payment order created for Rs " + amount + " using " + quote.pricingSource() + " pricing."
        );
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.FEE_ESTIMATE,
                "Fee estimated at order creation for " + paymentOrder.getSellerSubscriptionCode() + " plan"
        );

        Map<String, Object> response = new HashMap<>();
        response.put("orderId", razorpayOrder.get("id").toString());
        response.put("amount", toPaise(amount));
        response.put("currency", "INR");
        response.put("keyId", razorpayKeyId);
        response.put("itemTitle", item.getTitle());
        response.put("buyerEmail", buyer.getEmail());
        response.put("buyerName", buyer.getName());
        response.put("buyerPhone", buyer.getPhone() != null ? buyer.getPhone() : "");
        response.put("displayAmount", amount);
        response.put("pricingSource", quote.pricingSource());
        attachFeeBreakdown(response, paymentOrder);
        return response;
    }

    @Transactional
    public Map<String, Object> verifyPayment(
            String razorpayOrderId,
            String razorpayPaymentId,
            String razorpaySignature,
            Long buyerId
    ) throws Exception {
        requireGatewayConfigured();

        boolean valid = verifySignature(razorpayOrderId, razorpayPaymentId, razorpaySignature);
        if (!valid) {
            throw new RuntimeException("Payment verification failed. Invalid signature.");
        }

        PaymentOrder paymentOrder = paymentRepo.findByRazorpayOrderId(razorpayOrderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (!paymentOrder.getBuyer().getId().equals(buyerId)) {
            throw new RuntimeException("Unauthorized");
        }

        if (paymentOrder.getStatus() != PaymentStatus.CREATED) {
            if (razorpayPaymentId.equals(paymentOrder.getRazorpayPaymentId())) {
                return buildVerificationResponse(
                        paymentOrder,
                        "Payment already verified. Escrow status is " + paymentOrder.getStatus() + "."
                );
            }
            throw new RuntimeException("Order has already been processed in status " + paymentOrder.getStatus());
        }

        RazorpayClient client = buildRazorpayClient();
        Payment payment = client.payments.fetch(razorpayPaymentId);
        String method = payment.has("method") ? String.valueOf(payment.get("method")) : "unknown";
        String paymentStatus = payment.has("status") ? String.valueOf(payment.get("status")) : "";
        if (!SUCCESSFUL_PAYMENT_STATUSES.contains(paymentStatus)) {
            throw new RuntimeException("Payment is not captured yet. Current status: " + paymentStatus);
        }

        applyEscrowHold(
                paymentOrder,
                razorpayPaymentId,
                razorpaySignature,
                method,
                buyerId,
                "Payment of Rs " + paymentOrder.getAmount() + " received via " + method
                        + ". Held in escrow for " + escrowAutoReleaseHours + "h."
        );

        return buildVerificationResponse(
                paymentOrder,
                "Payment successful! Rs " + paymentOrder.getAmount()
                        + " is held in escrow. Confirm delivery to release funds."
        );
    }

    @Transactional
    public Map<String, Object> confirmDelivery(Long orderId, Long buyerId) {
        PaymentOrder paymentOrder = paymentRepo.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (!paymentOrder.getBuyer().getId().equals(buyerId)) {
            throw new RuntimeException("Unauthorized");
        }
        if (paymentOrder.getStatus() != PaymentStatus.ESCROW_HOLD) {
            throw new RuntimeException(
                    "Cannot confirm delivery in current state: " + paymentOrder.getStatus()
            );
        }

        releaseEscrow(
                paymentOrder,
                buyerId,
                "Buyer confirmed delivery.",
                "Escrow released to seller: Rs " + paymentOrder.getSellerNetAmount()
                        + " after platform fee of Rs " + paymentOrder.getPlatformFeeAmount()
        );

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put(
                "message",
                "Delivery confirmed! Rs " + paymentOrder.getSellerNetAmount()
                        + " released to seller after commission."
        );
        result.put("status", PaymentStatus.RELEASED.name());
        attachFeeBreakdown(result, paymentOrder);
        return result;
    }

    @Transactional
    public Map<String, Object> raiseDispute(Long orderId, Long buyerId, String reason) {
        PaymentOrder paymentOrder = paymentRepo.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (!paymentOrder.getBuyer().getId().equals(buyerId)) {
            throw new RuntimeException("Unauthorized");
        }
        if (paymentOrder.getStatus() != PaymentStatus.ESCROW_HOLD) {
            throw new RuntimeException("No active escrow to dispute");
        }

        paymentOrder.setStatus(PaymentStatus.DISPUTED);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        logEvent(paymentOrder, EventType.DISPUTE_RAISED, buyerId, "Dispute raised: " + reason);
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.DISPUTED,
                "Dispute raised. Platform fee and seller payout remain on hold."
        );

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("message", "Dispute raised. Admin will review within 24-48 hours.");
        result.put("status", PaymentStatus.DISPUTED.name());
        attachFeeBreakdown(result, paymentOrder);
        return result;
    }

    @Transactional
    public Map<String, Object> cancelOrder(Long orderId, Long buyerId) {
        PaymentOrder paymentOrder = paymentRepo.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (!paymentOrder.getBuyer().getId().equals(buyerId)) {
            throw new RuntimeException("Unauthorized");
        }
        if (paymentOrder.getStatus() != PaymentStatus.CREATED) {
            throw new RuntimeException(
                    "Cannot cancel order in " + paymentOrder.getStatus() + " state. Only unpaid orders can be cancelled."
            );
        }

        paymentOrder.setStatus(PaymentStatus.CANCELLED);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        restoreItemAvailability(paymentOrder.getItem());

        logEvent(paymentOrder, EventType.ORDER_CANCELLED, buyerId, "Order cancelled by buyer");
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.CANCELLED,
                "Order cancelled before payment release."
        );

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("message", "Order cancelled successfully");
        result.put("status", PaymentStatus.CANCELLED.name());
        attachFeeBreakdown(result, paymentOrder);
        return result;
    }

    @Transactional
    @Scheduled(cron = "0 0 * * * *")
    public void autoReleaseExpiredEscrow() {
        List<PaymentOrder> expired = paymentRepo
                .findByStatusAndEscrowReleasedFalseAndReleaseDeadlineBefore(
                        PaymentStatus.ESCROW_HOLD,
                        LocalDateTime.now()
                );

        for (PaymentOrder paymentOrder : expired) {
            releaseEscrow(
                    paymentOrder,
                    null,
                    "Auto-release triggered after escrow deadline elapsed.",
                    "Auto-released after " + escrowAutoReleaseHours + " hours."
            );
            log.info("[Escrow] Auto-released order {}", paymentOrder.getId());
        }
    }

    public List<PaymentOrder> getBuyerOrders(Long buyerId) {
        return paymentRepo.findByBuyerIdOrderByCreatedAtDesc(buyerId);
    }

    public List<PaymentOrder> getSellerOrders(Long sellerId) {
        return paymentRepo.findBySellerIdOrderByCreatedAtDesc(sellerId);
    }

    public List<EscrowEvent> getOrderTimeline(Long orderId) {
        return escrowEventRepo.findByOrderIdOrderByCreatedAtAsc(orderId);
    }

    public Optional<PaymentOrder> getOrderById(Long orderId) {
        return paymentRepo.findById(orderId);
    }

    public Optional<PaymentOrder> getOrderByItemId(Long itemId) {
        List<PaymentOrder> orders = paymentRepo.findByItemId(itemId);
        return orders.stream().findFirst();
    }

    @Transactional
    public Map<String, Object> refundOrder(Long orderId, Long adminId, String reason) {
        PaymentOrder paymentOrder = paymentRepo.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (paymentOrder.getStatus() != PaymentStatus.PAID
                && paymentOrder.getStatus() != PaymentStatus.DISPUTED
                && paymentOrder.getStatus() != PaymentStatus.ESCROW_HOLD) {
            throw new RuntimeException("Cannot refund order in " + paymentOrder.getStatus() + " state");
        }

        markOrderRefunded(paymentOrder, adminId, reason);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("message", "Payment refunded to buyer: Rs " + paymentOrder.getAmount());
        result.put("status", PaymentStatus.REFUNDED.name());
        result.put("amount", paymentOrder.getAmount().toString());
        result.put("reason", reason);
        attachFeeBreakdown(result, paymentOrder);
        return result;
    }

    public List<PaymentOrder> getDisputedOrders() {
        return paymentRepo.findByStatus(PaymentStatus.DISPUTED);
    }

    @Transactional
    public Map<String, Object> handleWebhook(String payload, String signature) {
        if (!isWebhookConfigured()) {
            throw new RuntimeException("Razorpay webhook secret is not configured");
        }
        if (signature == null || signature.isBlank() || !verifyWebhookSignature(payload, signature)) {
            throw new RuntimeException("Invalid Razorpay webhook signature");
        }

        JSONObject root = new JSONObject(payload);
        String event = root.optString("event", "");
        int updatedOrders = 0;

        switch (event) {
            case "payment.captured", "order.paid" -> updatedOrders = handleSuccessfulPaymentWebhook(root);
            case "payment.failed" -> updatedOrders = handleFailedPaymentWebhook(root);
            case "refund.processed" -> updatedOrders = handleRefundWebhook(root);
            default -> log.info("[Payments] Ignoring Razorpay webhook event {}", event);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("received", true);
        response.put("event", event);
        response.put("updatedOrders", updatedOrders);
        return response;
    }

    public Map<String, Object> getGatewayConfig() {
        Map<String, Object> response = new HashMap<>();
        response.put("keyId", razorpayKeyId == null ? "" : razorpayKeyId);
        response.put("configured", isGatewayConfigured());
        response.put("provider", "razorpay");
        response.put(
                "message",
                isGatewayConfigured()
                        ? "Razorpay payment gateway is configured."
                        : "Payments are disabled until Razorpay credentials are configured."
        );
        return response;
    }

    private void validateItemPurchasable(Item item, Long buyerId) {
        if (item.isDonation() || item.getListingType() == Item.ListingType.DONATION) {
            throw new RuntimeException("Donation listings cannot be purchased through Razorpay.");
        }

        if (item.getStatus() != Item.ItemStatus.AVAILABLE
                && !(item.getStatus() == Item.ItemStatus.RESERVED
                && item.getReservedBy() != null
                && item.getReservedBy().equals(buyerId))) {
            throw new RuntimeException("Item is no longer available for purchase");
        }

        if (item.getSeller() != null && item.getSeller().getId().equals(buyerId)) {
            throw new RuntimeException("Cannot buy your own item");
        }
    }

    private OrderQuote resolveOrderQuote(Item item, Long buyerId, BigDecimal quotedAmount, String notes) {
        Optional<Offer> acceptedOffer = offerRepo.findByItemIdAndBuyerIdAndStatus(
                item.getId(),
                buyerId,
                Offer.OfferStatus.ACCEPTED
        );

        BigDecimal authoritativeAmount = normalizeAmount(item.getPrice());
        String pricingSource = "ITEM_PRICE";
        String effectiveNotes = notes;

        if (acceptedOffer.isPresent()) {
            authoritativeAmount = normalizeAmount(BigDecimal.valueOf(acceptedOffer.get().getOfferedPrice()));
            pricingSource = "ACCEPTED_OFFER";
            effectiveNotes = appendOfferNotes(notes, acceptedOffer.get());
        }

        if (authoritativeAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("Item price must be greater than zero to create a payment order");
        }

        if (quotedAmount != null && quotedAmount.compareTo(authoritativeAmount) != 0) {
            log.warn(
                    "[Payments] Client quoted amount {} ignored for item {} buyer {}. Using authoritative amount {} from {}.",
                    quotedAmount, item.getId(), buyerId, authoritativeAmount, pricingSource
            );
        }

        return new OrderQuote(authoritativeAmount, pricingSource, effectiveNotes);
    }

    private String appendOfferNotes(String notes, Offer offer) {
        if (offer == null) {
            return notes;
        }
        if (notes == null || notes.isBlank()) {
            return "Accepted offer payment #" + offer.getId();
        }
        return notes + " | Accepted offer #" + offer.getId();
    }

    private RazorpayClient buildRazorpayClient() throws Exception {
        requireGatewayConfigured();
        return new RazorpayClient(razorpayKeyId, razorpayKeySecret);
    }

    private void requireGatewayConfigured() {
        if (!isGatewayConfigured()) {
            throw new RuntimeException(
                    "Razorpay credentials are not configured. Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET to enable payments."
            );
        }
    }

    private boolean isGatewayConfigured() {
        return razorpayKeyId != null && !razorpayKeyId.isBlank()
                && razorpayKeySecret != null && !razorpayKeySecret.isBlank();
    }

    private boolean isWebhookConfigured() {
        return razorpayWebhookSecret != null && !razorpayWebhookSecret.isBlank();
    }

    private int toPaise(BigDecimal amount) {
        return amount.multiply(HUNDRED).setScale(0, RoundingMode.HALF_UP).intValueExact();
    }

    private BigDecimal normalizeAmount(BigDecimal amount) {
        if (amount == null) {
            return BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        return amount.setScale(2, RoundingMode.HALF_UP);
    }

    private String buildReceipt(Long itemId, Long buyerId) {
        return "rcpt_" + itemId + "_" + buyerId + "_" + System.currentTimeMillis();
    }

    private void applyEscrowHold(
            PaymentOrder paymentOrder,
            String razorpayPaymentId,
            String razorpaySignature,
            String method,
            Long triggeredBy,
            String description
    ) {
        if (paymentOrder.getStatus() != PaymentStatus.CREATED) {
            return;
        }

        paymentOrder.setRazorpayPaymentId(razorpayPaymentId);
        if (razorpaySignature != null && !razorpaySignature.isBlank()) {
            paymentOrder.setRazorpaySignature(razorpaySignature);
        }
        paymentOrder.setStatus(PaymentStatus.ESCROW_HOLD);
        paymentOrder.setPaymentMethod(method);
        paymentOrder.setReleaseDeadline(LocalDateTime.now().plusHours(escrowAutoReleaseHours));
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        Item item = paymentOrder.getItem();
        item.setStatus(Item.ItemStatus.RESERVED);
        item.setReservedBy(paymentOrder.getBuyer().getId());
        itemRepo.save(item);

        logEvent(paymentOrder, EventType.PAYMENT_RECEIVED, triggeredBy, description);
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.ESCROW_HOLD,
                "Escrow hold created. Platform fee reserved until delivery confirmation."
        );
    }

    private void releaseEscrow(
            PaymentOrder paymentOrder,
            Long triggeredBy,
            String confirmationDescription,
            String releaseDescription
    ) {
        if (paymentOrder.getStatus() == PaymentStatus.RELEASED) {
            return;
        }

        paymentOrder.setStatus(PaymentStatus.RELEASED);
        paymentOrder.setEscrowReleased(true);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        Item item = paymentOrder.getItem();
        item.setStatus(Item.ItemStatus.SOLD);
        item.setReservedBy(paymentOrder.getBuyer().getId());
        itemRepo.save(item);

        if (confirmationDescription != null && !confirmationDescription.isBlank()) {
            logEvent(paymentOrder, EventType.DELIVERY_CONFIRMED, triggeredBy, confirmationDescription);
        }
        logEvent(paymentOrder, EventType.ESCROW_RELEASED, triggeredBy, releaseDescription);
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.RELEASED,
                "Payment released. Seller net payout: Rs " + paymentOrder.getSellerNetAmount()
        );
    }

    private void restoreItemAvailability(Item item) {
        item.setStatus(Item.ItemStatus.AVAILABLE);
        item.setReservedBy(null);
        itemRepo.save(item);
    }

    private void markOrderRefunded(PaymentOrder paymentOrder, Long triggeredBy, String reason) {
        if (paymentOrder.getStatus() == PaymentStatus.REFUNDED) {
            return;
        }

        paymentOrder.setStatus(PaymentStatus.REFUNDED);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        restoreItemAvailability(paymentOrder.getItem());

        logEvent(
                paymentOrder,
                EventType.REFUND_INITIATED,
                triggeredBy,
                "Refund initiated. Reason: " + reason
        );
        logEvent(
                paymentOrder,
                EventType.REFUND_DONE,
                triggeredBy,
                "Refund completed to buyer: Rs " + paymentOrder.getAmount()
        );
        monetizationService.recordCommissionEvent(
                paymentOrder,
                EntryType.REFUNDED,
                "Refund processed. Platform fee reversed for buyer protection."
        );
    }

    private void markOrderFailed(PaymentOrder paymentOrder, String description) {
        if (paymentOrder.getStatus() != PaymentStatus.CREATED) {
            return;
        }

        paymentOrder.setStatus(PaymentStatus.FAILED);
        paymentOrder.setUpdatedAt(LocalDateTime.now());
        paymentRepo.save(paymentOrder);

        restoreItemAvailability(paymentOrder.getItem());
        logEvent(paymentOrder, EventType.PAYMENT_FAILED, null, description);
    }

    private Map<String, Object> buildVerificationResponse(PaymentOrder paymentOrder, String message) {
        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("orderId", paymentOrder.getId());
        result.put("razorpayOrderId", paymentOrder.getRazorpayOrderId());
        result.put("paymentId", paymentOrder.getRazorpayPaymentId());
        result.put("amount", paymentOrder.getAmount());
        result.put("status", paymentOrder.getStatus().name());
        result.put("message", message);
        if (paymentOrder.getReleaseDeadline() != null) {
            result.put("releaseDeadline", paymentOrder.getReleaseDeadline().toString());
        }
        attachFeeBreakdown(result, paymentOrder);
        return result;
    }

    private int handleSuccessfulPaymentWebhook(JSONObject root) {
        JSONObject paymentEntity = optNested(root, "payload", "payment", "entity");
        String razorpayOrderId = paymentEntity.optString("order_id", "");
        String paymentId = paymentEntity.optString("id", "");
        String method = paymentEntity.optString("method", "unknown");
        String status = paymentEntity.optString("status", "");

        if (!SUCCESSFUL_PAYMENT_STATUSES.contains(status)) {
            log.info("[Payments] Webhook payment success ignored for non-success status {}", status);
            return 0;
        }

        PaymentOrder paymentOrder = findOrderForWebhook(razorpayOrderId, paymentId)
                .orElse(null);
        if (paymentOrder == null) {
            log.warn("[Payments] Razorpay webhook could not map successful payment to local order. orderId={}, paymentId={}", razorpayOrderId, paymentId);
            return 0;
        }

        if (paymentOrder.getStatus() == PaymentStatus.CREATED) {
            applyEscrowHold(
                    paymentOrder,
                    paymentId,
                    null,
                    method,
                    null,
                    "Payment reconciled from Razorpay webhook via " + method + "."
            );
            return 1;
        }
        return 0;
    }

    private int handleFailedPaymentWebhook(JSONObject root) {
        JSONObject paymentEntity = optNested(root, "payload", "payment", "entity");
        String razorpayOrderId = paymentEntity.optString("order_id", "");
        String paymentId = paymentEntity.optString("id", "");
        String reason = paymentEntity.optString("error_description", paymentEntity.optString("status", "Payment failed"));

        PaymentOrder paymentOrder = findOrderForWebhook(razorpayOrderId, paymentId)
                .orElse(null);
        if (paymentOrder == null) {
            log.warn("[Payments] Razorpay webhook could not map failed payment to local order. orderId={}, paymentId={}", razorpayOrderId, paymentId);
            return 0;
        }

        markOrderFailed(paymentOrder, "Payment failed according to Razorpay webhook: " + reason);
        return 1;
    }

    private int handleRefundWebhook(JSONObject root) {
        JSONObject refundEntity = optNested(root, "payload", "refund", "entity");
        String paymentId = refundEntity.optString("payment_id", "");
        String reason = refundEntity.optString("notes", "Refund processed by Razorpay webhook");

        if (paymentId.isBlank()) {
            return 0;
        }

        PaymentOrder paymentOrder = paymentRepo.findByRazorpayPaymentId(paymentId)
                .orElse(null);
        if (paymentOrder == null) {
            log.warn("[Payments] Razorpay refund webhook could not map payment {}", paymentId);
            return 0;
        }

        markOrderRefunded(paymentOrder, null, reason);
        return 1;
    }

    private Optional<PaymentOrder> findOrderForWebhook(String razorpayOrderId, String paymentId) {
        if (razorpayOrderId != null && !razorpayOrderId.isBlank()) {
            Optional<PaymentOrder> byOrderId = paymentRepo.findByRazorpayOrderId(razorpayOrderId);
            if (byOrderId.isPresent()) {
                return byOrderId;
            }
        }

        if (paymentId != null && !paymentId.isBlank()) {
            return paymentRepo.findByRazorpayPaymentId(paymentId);
        }

        return Optional.empty();
    }

    private JSONObject optNested(JSONObject root, String... path) {
        JSONObject current = root;
        for (String key : path) {
            JSONObject nested = current.optJSONObject(key);
            if (nested == null) {
                return new JSONObject();
            }
            current = nested;
        }
        return current;
    }

    private boolean verifySignature(String orderId, String paymentId, String signature) {
        return verifyHmacSignature(orderId + "|" + paymentId, signature, razorpayKeySecret);
    }

    private boolean verifyWebhookSignature(String payload, String signature) {
        return verifyHmacSignature(payload, signature, razorpayWebhookSecret);
    }

    private boolean verifyHmacSignature(String payload, String signature, String secret) {
        if (signature == null || signature.isBlank() || secret == null || secret.isBlank()) {
            return false;
        }

        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString().equals(signature);
        } catch (Exception e) {
            log.warn("Signature verification error: {}", e.getMessage());
            return false;
        }
    }

    private void logEvent(
            PaymentOrder paymentOrder,
            EventType type,
            Long triggeredBy,
            String description
    ) {
        EscrowEvent event = new EscrowEvent();
        event.setOrder(paymentOrder);
        event.setEventType(type);
        event.setTriggeredBy(triggeredBy);
        event.setDescription(description);
        escrowEventRepo.save(event);
    }

    private void attachFeeBreakdown(Map<String, Object> response, PaymentOrder order) {
        response.put("platformFeePercent", order.getPlatformFeePercent());
        response.put("platformFeeAmount", order.getPlatformFeeAmount());
        response.put("sellerNetAmount", order.getSellerNetAmount());
        response.put("sellerSubscriptionCode", order.getSellerSubscriptionCode());
    }

    private record OrderQuote(BigDecimal amount, String pricingSource, String notes) {
    }
}

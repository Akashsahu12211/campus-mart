package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "payment_orders")
@Data
@NoArgsConstructor
public class PaymentOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "razorpay_order_id", nullable = false, unique = true)
    private String razorpayOrderId;

    @Column(name = "razorpay_payment_id")
    private String razorpayPaymentId;

    @Column(name = "razorpay_signature")
    private String razorpaySignature;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "buyer_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student buyer;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "seller_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student seller;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id", nullable = false)
    @JsonIgnoreProperties({"seller", "imageUrls", "description"})
    private Item item;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "platform_fee_percent", precision = 5, scale = 2)
    private BigDecimal platformFeePercent = BigDecimal.ZERO;

    @Column(name = "platform_fee_amount", precision = 10, scale = 2)
    private BigDecimal platformFeeAmount = BigDecimal.ZERO;

    @Column(name = "seller_net_amount", precision = 10, scale = 2)
    private BigDecimal sellerNetAmount = BigDecimal.ZERO;

    @Column(name = "seller_subscription_code")
    private String sellerSubscriptionCode = "FREE";

    private String currency = "INR";

    @Enumerated(EnumType.STRING)
    private PaymentStatus status = PaymentStatus.CREATED;

    @Column(name = "payment_method")
    private String paymentMethod;

    private String notes;

    @Column(name = "escrow_released")
    private boolean escrowReleased = false;

    @Column(name = "release_deadline")
    private LocalDateTime releaseDeadline;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    public enum PaymentStatus {
        CREATED, PAID, FAILED, REFUNDED,
        ESCROW_HOLD, RELEASED, DISPUTED, CANCELLED
    }
}

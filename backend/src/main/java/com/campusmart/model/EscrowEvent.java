package com.campusmart.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "escrow_events")
@Data
@NoArgsConstructor
public class EscrowEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "order_id", nullable = false)
    private PaymentOrder order;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type")
    private EventType eventType;

    @Column(name = "triggered_by")
    private Long triggeredBy;

    private String description;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    public enum EventType {
        ORDER_CREATED, PAYMENT_RECEIVED,
        DELIVERY_CONFIRMED, ESCROW_RELEASED,
        DISPUTE_RAISED, DISPUTE_RESOLVED,
        REFUND_INITIATED, REFUND_DONE,
        PAYMENT_FAILED, ORDER_CANCELLED
    }
}

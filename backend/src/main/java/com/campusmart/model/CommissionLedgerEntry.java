package com.campusmart.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "commission_ledger_entries")
@Data
@NoArgsConstructor
public class CommissionLedgerEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "order_id", nullable = false)
    @JsonIgnoreProperties({"buyer", "seller", "item"})
    private PaymentOrder order;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "seller_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student seller;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "buyer_id", nullable = false)
    @JsonIgnoreProperties({"listedItems", "password"})
    private Student buyer;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id", nullable = false)
    @JsonIgnoreProperties({"seller", "imageUrls", "description"})
    private Item item;

    @Enumerated(EnumType.STRING)
    @Column(name = "entry_type", nullable = false)
    private EntryType entryType = EntryType.FEE_ESTIMATE;

    @Column(name = "gross_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal grossAmount = BigDecimal.ZERO;

    @Column(name = "fee_percent", nullable = false, precision = 5, scale = 2)
    private BigDecimal feePercent = BigDecimal.ZERO;

    @Column(name = "platform_fee_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal platformFeeAmount = BigDecimal.ZERO;

    @Column(name = "seller_net_amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal sellerNetAmount = BigDecimal.ZERO;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(columnDefinition = "TEXT")
    private String notes;

    public enum EntryType {
        FEE_ESTIMATE, ESCROW_HOLD, RELEASED, REFUNDED, CANCELLED, DISPUTED
    }
}

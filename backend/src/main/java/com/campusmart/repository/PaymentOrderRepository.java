package com.campusmart.repository;

import com.campusmart.model.PaymentOrder;
import com.campusmart.model.PaymentOrder.PaymentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentOrderRepository
        extends JpaRepository<PaymentOrder, Long> {

    Optional<PaymentOrder> findByRazorpayOrderId(String orderId);
    Optional<PaymentOrder> findByRazorpayPaymentId(String paymentId);
    List<PaymentOrder> findByBuyerIdOrderByCreatedAtDesc(Long buyerId);
    List<PaymentOrder> findBySellerIdOrderByCreatedAtDesc(Long sellerId);
    List<PaymentOrder> findByItemId(Long itemId);
    boolean existsByBuyerIdAndSellerIdAndItemIdAndStatus(Long buyerId, Long sellerId, Long itemId, PaymentStatus status);
    List<PaymentOrder> findByStatusAndEscrowReleasedFalseAndReleaseDeadlineBefore(
        PaymentStatus status, LocalDateTime now);
    List<PaymentOrder> findByStatusOrderByCreatedAtDesc(PaymentStatus status);
    List<PaymentOrder> findByStatus(PaymentStatus status);
    
    // ── Admin Analytics Aggregation (prevents N+1 queries) ──
    @Query("SELECT SUM(COALESCE(p.amount, 0)) FROM PaymentOrder p WHERE p.status = 'RELEASED'")
    BigDecimal sumReleasedAmount();
    
    @Query("SELECT SUM(COALESCE(p.amount, 0)) FROM PaymentOrder p WHERE p.status = 'PAID' OR p.status = 'ESCROW_HOLD' OR p.status = 'DISPUTED'")
    BigDecimal sumPendingAmount();
    
    @Query("SELECT SUM(COALESCE(p.platformFeeAmount, 0)) FROM PaymentOrder p WHERE p.status = 'RELEASED'")
    BigDecimal sumReleasedPlatformFees();
    
    @Query("SELECT SUM(COALESCE(p.platformFeeAmount, 0)) FROM PaymentOrder p WHERE p.status = 'PAID' OR p.status = 'ESCROW_HOLD' OR p.status = 'DISPUTED'")
    BigDecimal sumPendingPlatformFees();
}

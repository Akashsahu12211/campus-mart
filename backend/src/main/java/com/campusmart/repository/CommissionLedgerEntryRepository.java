package com.campusmart.repository;

import com.campusmart.model.CommissionLedgerEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommissionLedgerEntryRepository extends JpaRepository<CommissionLedgerEntry, Long> {

    List<CommissionLedgerEntry> findTop20BySellerIdOrderByCreatedAtDesc(Long sellerId);

    List<CommissionLedgerEntry> findByOrderIdOrderByCreatedAtAsc(Long orderId);
}

package com.campusmart.repository;

import com.campusmart.model.EscrowEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface EscrowEventRepository
        extends JpaRepository<EscrowEvent, Long> {
    List<EscrowEvent> findByOrderIdOrderByCreatedAtAsc(Long orderId);
}

package com.campusmart.repository;

import com.campusmart.model.Wishlist;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

public interface WishlistRepository extends JpaRepository<Wishlist, Long> {
    List<Wishlist> findByStudentId(Long studentId);
    Optional<Wishlist> findByStudentIdAndItemId(Long studentId, Long itemId);
    boolean existsByStudentIdAndItemId(Long studentId, Long itemId);
    
    @Modifying
    @Transactional
    void deleteByStudentIdAndItemId(Long studentId, Long itemId);

    long countByStudentId(Long studentId);
}
package com.campusmart.repository;

import com.campusmart.model.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    List<Review> findBySellerId(Long sellerId);
    List<Review> findByReviewerId(Long reviewerId);
    List<Review> findByItemId(Long itemId);
    boolean existsByReviewerIdAndItemId(Long reviewerId, Long itemId);
    Optional<Review> findByReviewerIdAndItemId(Long reviewerId, Long itemId);

    @Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.seller.id = :sellerId")
    Double getAverageRatingBySellerId(@Param("sellerId") Long sellerId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.seller.id = :sellerId")
    Long countBySellerId(@Param("sellerId") Long sellerId);

    @Query("""
        SELECT r.seller.id, COALESCE(AVG(r.rating), 0), COUNT(r)
        FROM Review r
        WHERE r.seller.id IN :sellerIds
        GROUP BY r.seller.id
    """)
    List<Object[]> getSellerRatingSummaries(@Param("sellerIds") Collection<Long> sellerIds);
}

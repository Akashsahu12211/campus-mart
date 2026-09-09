package com.campusmart.repository;

import com.campusmart.model.Item;
import com.campusmart.model.Item.ItemStatus;
import jakarta.transaction.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface ItemRepository extends JpaRepository<Item, Long>, ItemRepositoryCustom {
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByStatus(ItemStatus status);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByStatusOrderByCreatedAtDesc(ItemStatus status);
    List<Item> findByCategoryId(Long categoryId);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findBySellerIdOrderByCreatedAtDesc(Long sellerId);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByTitleContainingIgnoreCaseAndStatus(String title, ItemStatus status);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByCategoryIdAndStatus(Long categoryId, ItemStatus status);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findTop8ByStatusOrderByCreatedAtDesc(ItemStatus status);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findTop8ByCategoryIdAndStatusAndIdNotOrderByCreatedAtDesc(Long categoryId, ItemStatus status, Long id);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findTop8ByListingTypeAndStatusAndIdNotOrderByCreatedAtDesc(Item.ListingType listingType, ItemStatus status, Long id);
    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findTop8ByListingTypeAndAcademicSubjectIgnoreCaseAndStatusAndIdNotOrderByCreatedAtDesc(
        Item.ListingType listingType, String academicSubject, ItemStatus status, Long id);

    long countBySellerId(Long sellerId);
    long countBySellerIdAndStatus(Long sellerId, Item.ItemStatus status);
    long countBySellerIdAndBoostExpiresAtAfter(Long sellerId, java.time.LocalDateTime dateTime);
    long countByBoostExpiresAtAfter(java.time.LocalDateTime dateTime);

    @Query("SELECT COALESCE(SUM(i.viewCount), 0) FROM Item i WHERE i.seller.id = :sellerId")
    long sumViewCountBySellerId(@Param("sellerId") Long sellerId);

    @Query("SELECT i FROM Item i WHERE " +
           "i.status = :status AND " +
           "(:q IS NULL OR LOWER(i.title) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           " LOWER(i.description) LIKE LOWER(CONCAT('%', :q, '%'))) AND " +
           "(:categoryId IS NULL OR i.category.id = :categoryId) AND " +
           "(:listingType IS NULL OR i.listingType = :listingType) AND " +
           "(:donation IS NULL OR i.donation = :donation) AND " +
           "(:minPrice IS NULL OR i.price >= :minPrice) AND " +
           "(:maxPrice IS NULL OR i.price <= :maxPrice) AND " +
           "(:negotiable IS NULL OR i.negotiable = :negotiable) AND " +
           "(:hostel IS NULL OR LOWER(i.seller.hostel) = LOWER(:hostel)) AND " +
           "(:branch IS NULL OR LOWER(i.seller.branch) = LOWER(:branch))")
    List<Item> findWithFilters(
        @Param("q")          String q,
        @Param("categoryId") Long categoryId,
        @Param("listingType") Item.ListingType listingType,
        @Param("donation") Boolean donation,
        @Param("minPrice")   java.math.BigDecimal minPrice,
        @Param("maxPrice")   java.math.BigDecimal maxPrice,
        @Param("negotiable") Boolean negotiable,
        @Param("hostel")     String hostel,
        @Param("branch")     String branch,
        @Param("status")     ItemStatus status
    );

    @Query("SELECT i FROM Item i WHERE i.status = :status AND i.reservedBy = :buyerId ORDER BY i.createdAt DESC")
    List<Item> findReservedItemsByBuyer(
        @Param("status") ItemStatus status,
        @Param("buyerId") Long buyerId
    );

    @Query("SELECT i FROM Item i WHERE i.status = :status AND i.seller.id = :sellerId AND i.reservedBy IS NOT NULL ORDER BY i.createdAt DESC")
    List<Item> findReservedItemsBySeller(
        @Param("status") ItemStatus status,
        @Param("sellerId") Long sellerId
    );

    // ✅ PAGINATION METHOD
    @EntityGraph(attributePaths = {"seller", "category"})
    Page<Item> findByStatus(ItemStatus status, Pageable pageable);

    @Modifying
    @Transactional
    @Query("UPDATE Item i SET i.viewCount = i.viewCount + 1 WHERE i.id = :itemId")
    int incrementViewCount(@Param("itemId") Long itemId);

    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByStatusAndCreatedAtBetweenOrderByCreatedAtAsc(
        ItemStatus status,
        LocalDateTime from,
        LocalDateTime to
    );

    @EntityGraph(attributePaths = {"seller", "category"})
    List<Item> findByStatusAndCreatedAtBeforeOrderByCreatedAtAsc(
        ItemStatus status,
        LocalDateTime before
    );

    // ── Admin Panel Methods ────────────────────────────────
    long countByStatus(ItemStatus status);
    long countByCreatedAtAfter(java.time.LocalDateTime date);
    long countByCreatedAtBetween(
        java.time.LocalDateTime from,
        java.time.LocalDateTime to);
    List<Item> findAllByOrderByCreatedAtDesc();

    @Query("SELECT i.category.name, COUNT(i) FROM Item i " +
           "WHERE i.category IS NOT NULL " +
           "GROUP BY i.category.name " +
           "ORDER BY COUNT(i) DESC")
    List<Object[]> countByCategory();

    @Query("SELECT DISTINCT i FROM Item i JOIN i.imageUrls imageUrl WHERE imageUrl LIKE 'data:%'")
    List<Item> findItemsWithInlineImages();
}

package com.campusmart.repository;

import com.campusmart.model.Offer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface OfferRepository extends JpaRepository<Offer, Long> {
    
    // Get all offers for an item
    List<Offer> findByItemId(Long itemId);
    
    // Get all offers from a buyer
    List<Offer> findByBuyerId(Long buyerId);
    
    // Get all offers received by a seller (offers on their items)
    @Query("SELECT o FROM Offer o WHERE o.item.seller.id = :sellerId")
    List<Offer> findBySellerId(@Param("sellerId") Long sellerId);
    
    // Get offers for an item by status
    @Query("SELECT o FROM Offer o WHERE o.item.id = :itemId AND o.status = :status")
    List<Offer> findByItemIdAndStatus(@Param("itemId") Long itemId, @Param("status") Offer.OfferStatus status);

    Optional<Offer> findByItemIdAndBuyerIdAndStatus(Long itemId, Long buyerId, Offer.OfferStatus status);
}

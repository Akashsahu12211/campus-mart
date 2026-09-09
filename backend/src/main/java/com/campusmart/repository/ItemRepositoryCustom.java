package com.campusmart.repository;

import com.campusmart.model.Item;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public interface ItemRepositoryCustom {
    Page<Item> searchAvailableItems(
        String q,
        Long categoryId,
        Item.ListingType listingType,
        Boolean donation,
        BigDecimal minPrice,
        BigDecimal maxPrice,
        Item.ItemCondition condition,
        Boolean negotiable,
        String hostel,
        String branch,
        String sortKey,
        Double userLat,
        Double userLng,
        Double radiusKm,
        Pageable pageable,
        LocalDateTime now
    );
}

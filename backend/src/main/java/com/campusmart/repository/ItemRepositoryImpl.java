package com.campusmart.repository;

import com.campusmart.model.Item;
import com.campusmart.model.Student;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.TypedQuery;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Order;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Repository
public class ItemRepositoryImpl implements ItemRepositoryCustom {

    private static final double EARTH_RADIUS_KM = 6371.0;

    @PersistenceContext
    private EntityManager entityManager;

    @Override
    public Page<Item> searchAvailableItems(
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
    ) {
        CriteriaBuilder cb = entityManager.getCriteriaBuilder();

        CriteriaQuery<Item> query = cb.createQuery(Item.class);
        Root<Item> root = query.from(Item.class);
        root.fetch("seller", JoinType.LEFT);
        root.fetch("category", JoinType.LEFT);

        Join<Item, Student> seller = root.join("seller", JoinType.LEFT);
        List<Predicate> predicates = buildPredicates(
            cb,
            root,
            seller,
            q,
            categoryId,
            listingType,
            donation,
            minPrice,
            maxPrice,
            condition,
            negotiable,
            hostel,
            branch,
            userLat,
            userLng,
            radiusKm
        );

        query.select(root)
            .distinct(true)
            .where(predicates.toArray(new Predicate[0]))
            .orderBy(buildSortOrders(cb, root, seller, sortKey, userLat, userLng, now));

        TypedQuery<Item> typedQuery = entityManager.createQuery(query);
        typedQuery.setFirstResult((int) pageable.getOffset());
        typedQuery.setMaxResults(pageable.getPageSize());
        List<Item> content = typedQuery.getResultList();

        CriteriaQuery<Long> countQuery = cb.createQuery(Long.class);
        Root<Item> countRoot = countQuery.from(Item.class);
        Join<Item, Student> countSeller = countRoot.join("seller", JoinType.LEFT);
        List<Predicate> countPredicates = buildPredicates(
            cb,
            countRoot,
            countSeller,
            q,
            categoryId,
            listingType,
            donation,
            minPrice,
            maxPrice,
            condition,
            negotiable,
            hostel,
            branch,
            userLat,
            userLng,
            radiusKm
        );

        countQuery.select(cb.countDistinct(countRoot))
            .where(countPredicates.toArray(new Predicate[0]));

        long total = entityManager.createQuery(countQuery).getSingleResult();
        return new PageImpl<>(content, pageable, total);
    }

    private List<Predicate> buildPredicates(
        CriteriaBuilder cb,
        Root<Item> root,
        Join<Item, Student> seller,
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
        Double userLat,
        Double userLng,
        Double radiusKm
    ) {
        List<Predicate> predicates = new ArrayList<>();
        predicates.add(cb.equal(root.get("status"), Item.ItemStatus.AVAILABLE));

        if (q != null && !q.isBlank()) {
            String likePattern = "%" + q.trim().toLowerCase(Locale.ROOT) + "%";
            predicates.add(
                cb.or(
                    cb.like(cb.lower(root.get("title")), likePattern),
                    cb.like(cb.lower(root.get("description")), likePattern)
                )
            );
        }

        if (categoryId != null) {
            predicates.add(cb.equal(root.get("category").get("id"), categoryId));
        }

        if (listingType != null) {
            predicates.add(cb.equal(root.get("listingType"), listingType));
        }

        if (donation != null) {
            predicates.add(cb.equal(root.get("donation"), donation));
        }

        if (minPrice != null) {
            predicates.add(cb.greaterThanOrEqualTo(root.get("price"), minPrice));
        }

        if (maxPrice != null) {
            predicates.add(cb.lessThanOrEqualTo(root.get("price"), maxPrice));
        }

        if (condition != null) {
            predicates.add(cb.equal(root.get("condition"), condition));
        }

        if (negotiable != null) {
            predicates.add(cb.equal(root.get("negotiable"), negotiable));
        }

        if (hostel != null && !hostel.isBlank()) {
            predicates.add(cb.equal(cb.lower(seller.get("hostel")), hostel.trim().toLowerCase(Locale.ROOT)));
        }

        if (branch != null && !branch.isBlank()) {
            predicates.add(cb.equal(cb.lower(seller.get("branch")), branch.trim().toLowerCase(Locale.ROOT)));
        }

        if (hasLocationFilter(userLat, userLng, radiusKm)) {
            Expression<Double> distanceExpression = buildDistanceExpression(cb, seller, userLat, userLng);
            predicates.add(cb.isNotNull(seller.get("latitude")));
            predicates.add(cb.isNotNull(seller.get("longitude")));
            predicates.add(cb.lessThanOrEqualTo(distanceExpression, radiusKm));
        }

        return predicates;
    }

    private List<Order> buildSortOrders(
        CriteriaBuilder cb,
        Root<Item> root,
        Join<Item, Student> seller,
        String sortKey,
        Double userLat,
        Double userLng,
        LocalDateTime now
    ) {
        List<Order> orders = new ArrayList<>();
        Expression<Integer> boostRank = cb.<Integer>selectCase()
            .when(
                cb.and(
                    cb.isNotNull(root.get("boostExpiresAt")),
                    cb.greaterThan(root.get("boostExpiresAt"), now)
                ),
                0
            )
            .otherwise(1);

        orders.add(cb.asc(boostRank));
        orders.add(cb.desc(root.get("boostedAt")));

        String normalizedSort = sortKey == null ? "newest" : sortKey.trim().toLowerCase(Locale.ROOT);
        switch (normalizedSort) {
            case "price_low":
            case "price_asc":
                orders.add(cb.asc(root.get("price")));
                break;
            case "price_high":
            case "price_desc":
                orders.add(cb.desc(root.get("price")));
                break;
            case "popular":
                orders.add(cb.desc(root.get("viewCount")));
                break;
            case "nearby":
                if (userLat != null && userLng != null) {
                    orders.add(cb.asc(buildDistanceExpression(cb, seller, userLat, userLng)));
                    break;
                }
                orders.add(cb.desc(root.get("createdAt")));
                break;
            default:
                orders.add(cb.desc(root.get("createdAt")));
                break;
        }

        orders.add(cb.desc(root.get("id")));
        return orders;
    }

    private boolean hasLocationFilter(Double userLat, Double userLng, Double radiusKm) {
        return userLat != null && userLng != null && radiusKm != null && radiusKm > 0;
    }

    private Expression<Double> buildDistanceExpression(
        CriteriaBuilder cb,
        Path<?> seller,
        Double userLat,
        Double userLng
    ) {
        Expression<Double> userLatRad = cb.function("radians", Double.class, cb.literal(userLat));
        Expression<Double> userLngRad = cb.function("radians", Double.class, cb.literal(userLng));
        Expression<Double> sellerLatRad = cb.function("radians", Double.class, seller.get("latitude"));
        Expression<Double> sellerLngRad = cb.function("radians", Double.class, seller.get("longitude"));

        Expression<Double> cosPart = cb.prod(
            cb.function("cos", Double.class, userLatRad),
            cb.prod(
                cb.function("cos", Double.class, sellerLatRad),
                cb.function("cos", Double.class, cb.diff(sellerLngRad, userLngRad))
            )
        );

        Expression<Double> sinPart = cb.prod(
            cb.function("sin", Double.class, userLatRad),
            cb.function("sin", Double.class, sellerLatRad)
        );

        Expression<Double> rawDistanceSeed = cb.sum(cosPart, sinPart);
        Expression<Double> clampedSeed = cb.function(
            "least",
            Double.class,
            cb.literal(1.0),
            cb.function("greatest", Double.class, cb.literal(-1.0), rawDistanceSeed)
        );

        return cb.prod(
            cb.literal(EARTH_RADIUS_KM),
            cb.function("acos", Double.class, clampedSeed)
        );
    }
}

package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.*;
import com.campusmart.repository.PaymentOrderRepository;
import com.campusmart.repository.ReviewRepository;
import com.campusmart.repository.TransactionRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/reviews")
public class ReviewController {

    @Autowired private ReviewRepository reviewRepo;
    @Autowired private PaymentOrderRepository paymentOrderRepository;
    @Autowired private TransactionRepository transactionRepository;

    // Get all reviews for a seller
    @GetMapping("/seller/{sellerId}")
    public ResponseEntity<?> getSellerReviews(@PathVariable Long sellerId) {
        List<Review> reviews = reviewRepo.findBySellerId(sellerId);
        Double avg  = reviewRepo.getAverageRatingBySellerId(sellerId);
        Long   count = reviewRepo.countBySellerId(sellerId);
        Map<String, Object> resp = new HashMap<>();
        resp.put("reviews",       reviews);
        double safeAverage = avg == null ? 0.0 : avg;
        resp.put("averageRating", Math.round(safeAverage * 10.0) / 10.0);
        resp.put("totalReviews",  count);
        return ResponseEntity.ok(resp);
    }

    // Get all reviews for a specific item
    @GetMapping("/item/{itemId}")
    public ResponseEntity<?> getItemReviews(@PathVariable Long itemId) {
        List<Review> reviews = reviewRepo.findByItemId(itemId);
        return ResponseEntity.ok(Map.of("reviews", reviews));
    }

    // Check if reviewer already reviewed this item
    @GetMapping("/check")
    public ResponseEntity<?> checkReview(
            @RequestParam Long reviewerId,
            @RequestParam Long itemId) {
        SecurityUtils.requireCurrentUser(reviewerId);
        boolean exists = reviewRepo.existsByReviewerIdAndItemId(reviewerId, itemId);
        return ResponseEntity.ok(Map.of("reviewed", exists));
    }

    // Add new review
    @PostMapping
    public ResponseEntity<?> addReview(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        Long reviewerId = SecurityUtils.getCurrentUserId();
        Long sellerId   = Long.valueOf(body.get("sellerId").toString());
        Long itemId     = Long.valueOf(body.get("itemId").toString());
        int  rating     = Integer.parseInt(body.get("rating").toString());
        String comment  = (String) body.getOrDefault("comment", "");

        if (rating < 1 || rating > 5) {
            return ResponseEntity.badRequest().body(Map.of("error", "Rating must be between 1 and 5"));
        }

        if (reviewRepo.existsByReviewerIdAndItemId(reviewerId, itemId)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Already reviewed"));
        }

        boolean hasCompletedOnlineOrder = paymentOrderRepository.existsByBuyerIdAndSellerIdAndItemIdAndStatus(
            reviewerId,
            sellerId,
            itemId,
            PaymentOrder.PaymentStatus.RELEASED
        );
        boolean hasCompletedLegacyTransaction = transactionRepository.existsByBuyerIdAndSellerIdAndItemIdAndStatus(
            reviewerId,
            sellerId,
            itemId,
            Transaction.TransactionStatus.COMPLETED
        );

        if (!hasCompletedOnlineOrder && !hasCompletedLegacyTransaction) {
            return ResponseEntity.status(403).body(Map.of(
                "error", "Only buyers with a completed order can review this seller."
            ));
        }

        Review r = new Review();
        Student reviewer = new Student(); reviewer.setId(reviewerId); r.setReviewer(reviewer);
        Student seller   = new Student(); seller.setId(sellerId);     r.setSeller(seller);
        Item    item     = new Item();    item.setId(itemId);          r.setItem(item);
        r.setRating(rating);
        r.setComment(comment);
        return ResponseEntity.ok(reviewRepo.save(r));
    }

    // Delete review
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteReview(@PathVariable Long id, HttpServletRequest request) {
        return reviewRepo.findById(id).map(review -> {
            validateCurrentUser(request, review.getReviewer().getId());
            reviewRepo.deleteById(id);
            return ResponseEntity.ok(Map.of("message", "Deleted"));
        }).orElse(ResponseEntity.notFound().build());
    }

    // Update review
    @PutMapping("/{id}")
    public ResponseEntity<?> updateReview(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body,
            HttpServletRequest request) {
        return reviewRepo.findById(id).map(review -> {
            validateCurrentUser(request, review.getReviewer().getId());
            int rating = Integer.parseInt(body.get("rating").toString());
            String comment = (String) body.getOrDefault("comment", "");
            review.setRating(rating);
            review.setComment(comment);
            return ResponseEntity.ok(reviewRepo.save(review));
        }).orElse(ResponseEntity.notFound().build());
    }

    private void validateCurrentUser(HttpServletRequest request, Long expectedUserId) {
        if (!SecurityUtils.getCurrentUserId().equals(expectedUserId)) {
            throw new RuntimeException("Unauthorized");
        }
    }
}

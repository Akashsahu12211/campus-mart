package com.campusmart.controller;

import com.campusmart.model.*;
import com.campusmart.repository.WishlistRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/wishlist")
public class WishlistController {

    @Autowired private WishlistRepository wishlistRepo;

    // Get user's wishlist
    @GetMapping("/{studentId}")
    public ResponseEntity<?> getWishlist(@PathVariable Long studentId, HttpServletRequest request) {
        validateCurrentUser(request, studentId);
        return ResponseEntity.ok(wishlistRepo.findByStudentId(studentId));
    }

    // Check if item is wishlisted
    @GetMapping("/{studentId}/check/{itemId}")
    public ResponseEntity<Map<String, Boolean>> checkWishlist(
            @PathVariable Long studentId, @PathVariable Long itemId, HttpServletRequest request) {
        validateCurrentUser(request, studentId);
        boolean exists = wishlistRepo.existsByStudentIdAndItemId(studentId, itemId);
        return ResponseEntity.ok(Map.of("wishlisted", exists));
    }

    // Add to wishlist
    @PostMapping
    public ResponseEntity<?> addToWishlist(@RequestBody Map<String, Long> body, HttpServletRequest request) {
        Long studentId = body.get("studentId");
        Long itemId    = body.get("itemId");
        validateCurrentUser(request, studentId);
        if (wishlistRepo.existsByStudentIdAndItemId(studentId, itemId)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Already in wishlist"));
        }
        Wishlist w = new Wishlist();
        Student s = new Student(); s.setId(studentId); w.setStudent(s);
        Item item = new Item();   item.setId(itemId);  w.setItem(item);
        return ResponseEntity.ok(wishlistRepo.save(w));
    }

    // Remove from wishlist
    @DeleteMapping("/{studentId}/{itemId}")
    public ResponseEntity<?> removeFromWishlist(
            @PathVariable Long studentId, @PathVariable Long itemId, HttpServletRequest request) {
        validateCurrentUser(request, studentId);
        wishlistRepo.deleteByStudentIdAndItemId(studentId, itemId);
        return ResponseEntity.ok(Map.of("message", "Removed from wishlist"));
    }

    private void validateCurrentUser(HttpServletRequest request, Long studentId) {
        Object userId = request.getAttribute("userId");
        if (userId == null || !Long.valueOf(userId.toString()).equals(studentId)) {
            throw new RuntimeException("Unauthorized");
        }
    }
}

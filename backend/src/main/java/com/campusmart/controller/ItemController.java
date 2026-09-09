package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.dto.ItemUpsertRequest;
import com.campusmart.model.Item;
import com.campusmart.model.Item.ListingType;
import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import com.campusmart.service.ItemImageStorageService;
import com.campusmart.service.ItemService;
import com.campusmart.service.NotificationEventService;
import com.campusmart.util.OwnershipValidator;
import com.campusmart.util.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Valid;
import jakarta.validation.Validator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@RestController
@RequestMapping("/api/items")
public class ItemController {

    @Autowired
    private ItemService itemService;

    @Autowired
    private OwnershipValidator ownershipValidator;

    @Autowired
    private NotificationEventService notificationEventService;

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private RateLimiter rateLimiter;

    @Autowired(required = false)
    private ItemImageStorageService itemImageStorageService;

    @Autowired
    private Validator validator;

    @GetMapping
    public ResponseEntity<List<Item>> getAllAvailableItems(HttpServletRequest request) {
        List<Item> items = itemService.getAllAvailableItems();
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/paginated")
    public ResponseEntity<?> getPaginatedItems(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(defaultValue = "newest") String sort,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) ListingType listingType,
            @RequestParam(required = false) Boolean donation,
            @RequestParam(required = false) Double minPrice,
            @RequestParam(required = false) Double maxPrice,
            @RequestParam(required = false) String condition,
            @RequestParam(required = false) String hostel,
            @RequestParam(required = false) String branch,
            @RequestParam(required = false) Double userLat,
            @RequestParam(required = false) Double userLng,
            @RequestParam(required = false) Double radiusKm,
            HttpServletRequest request) {
        try {
            Student viewer = resolveViewer(request);
            Page<Item> result = itemService.searchAvailableItemsPage(
                q, categoryId, listingType, donation, minPrice, maxPrice,
                condition, null, hostel, branch,
                normalizeSort(sort), page, pageSize,
                userLat, userLng, radiusKm
            );
            itemService.prepareItemsForViewer(result.getContent(), viewer);
            return ResponseEntity.ok(Map.of(
                "content", result.getContent(),
                "totalPages", result.getTotalPages(),
                "totalElements", result.getTotalElements(),
                "currentPage", result.getNumber(),
                "pageSize", result.getSize()
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/recent")
    public ResponseEntity<List<Item>> getRecentItems(HttpServletRequest request) {
        List<Item> items = itemService.getRecentItems();
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/all")
    public ResponseEntity<List<Item>> getAllItems(HttpServletRequest request) {
        List<Item> items = itemService.getAllItems();
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getItemById(@PathVariable Long id, HttpServletRequest request) {
        Student viewer = resolveViewer(request);
        return itemService.getItemById(id)
                .<ResponseEntity<?>>map(item -> {
                    itemService.prepareItemForViewer(item, viewer);
                    return ResponseEntity.ok(item);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/similar")
    public ResponseEntity<?> getSimilarItems(@PathVariable Long id, HttpServletRequest request) {
        try {
            List<Item> items = itemService.getSimilarItems(id);
            itemService.prepareItemsForViewer(items, resolveViewer(request));
            return ResponseEntity.ok(items);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/category/{categoryId}")
    public ResponseEntity<List<Item>> getItemsByCategory(@PathVariable Long categoryId, HttpServletRequest request) {
        List<Item> items = itemService.getItemsByCategory(categoryId);
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/seller/{sellerId}")
    public ResponseEntity<List<Item>> getItemsBySeller(@PathVariable Long sellerId, HttpServletRequest request) {
        List<Item> items = itemService.getItemsBySeller(sellerId);
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/search")
    public ResponseEntity<List<Item>> searchItems(
            @RequestParam String q,
            @RequestParam(required = false) ListingType listingType,
            @RequestParam(required = false) Boolean donation,
            @RequestParam(required = false) Double minPrice,
            @RequestParam(required = false) Double maxPrice,
            @RequestParam(required = false) String condition,
            @RequestParam(required = false) String hostel,
            @RequestParam(required = false) String branch,
            @RequestParam(required = false) Double userLat,
            @RequestParam(required = false) Double userLng,
            @RequestParam(required = false) Double radiusKm,
            @RequestParam(defaultValue = "newest") String sort,
            HttpServletRequest request) {
        List<Item> items = itemService.searchAvailableItemsPage(
            q, null, listingType, donation, minPrice, maxPrice,
            condition, null, hostel, branch,
            normalizeSort(sort), 0, 100,
            userLat, userLng, radiusKm
        ).getContent();
        itemService.prepareItemsForViewer(items, resolveViewer(request));
        return ResponseEntity.ok(items);
    }

    @GetMapping("/reserved/buyer/{buyerId}")
    public ResponseEntity<List<Item>> getReservedItemsByBuyer(@PathVariable Long buyerId) {
        SecurityUtils.requireCurrentUser(buyerId);
        return ResponseEntity.ok(itemService.getReservedItemsByBuyer(buyerId));
    }

    @GetMapping("/reserved/seller/{sellerId}")
    public ResponseEntity<List<Item>> getReservedItemsBySeller(@PathVariable Long sellerId) {
        SecurityUtils.requireCurrentUser(sellerId);
        return ResponseEntity.ok(itemService.getReservedItemsBySeller(sellerId));
    }

    @PostMapping
    public ResponseEntity<?> addItem(@Valid @RequestBody ItemUpsertRequest itemRequest, HttpServletRequest request) {
        Long currentUserId = SecurityUtils.getCurrentUserId();
        if (!rateLimiter.allowCreateItem(String.valueOf(currentUserId))) {
            return ResponseEntity.status(429).body(Map.of(
                    "error", "Too many items created. Please try again later."
            ));
        }

        Student seller = studentRepository.findById(currentUserId)
            .orElseThrow(() -> new RuntimeException("Seller not found"));

        Item savedItem = itemService.createItem(itemRequest, seller);
        CompletableFuture.runAsync(() -> {
            try {
                notificationEventService.notifyNewItemAdded(savedItem);
            } catch (Exception e) {
                System.err.println("[NOTIFICATION] New item notification failed: " + e.getMessage());
            }
        });
        return ResponseEntity.ok(savedItem);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateItem(@PathVariable Long id, @RequestBody ItemUpsertRequest itemRequest, HttpServletRequest request) {
        Long userId = SecurityUtils.getCurrentUserId();
        ownershipValidator.validateItemOwnership(userId, id);
        validateUpsertRequest(itemRequest);
        return ResponseEntity.ok(itemService.updateItem(id, itemRequest));
    }

    @PostMapping(value = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadItemImage(@RequestParam("file") MultipartFile file) {
        if (itemImageStorageService == null) {
            throw new RuntimeException("Item image upload service is unavailable");
        }
        Long currentUserId = SecurityUtils.getCurrentUserId();
        String imageUrl = itemImageStorageService.storeItemImage(file, currentUserId);
        return ResponseEntity.ok(Map.of("url", imageUrl));
    }

    @PatchMapping("/{id}/sold")
    public ResponseEntity<?> markAsSold(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            ownershipValidator.validateItemOwnership(userId, id);
            return ResponseEntity.ok(itemService.markAsSold(id));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{id}/reserved")
    public ResponseEntity<?> markAsReserved(@PathVariable Long id) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            ownershipValidator.validateItemOwnership(userId, id);
            return ResponseEntity.ok(itemService.markAsReserved(id));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{id}/reserve-by-buyer")
    public ResponseEntity<?> reserveByBuyer(
            @PathVariable Long id,
            @RequestBody(required = false) Map<String, Long> body) {
        try {
            Long buyerId = SecurityUtils.getCurrentUserId();
            Item item = itemService.getItemById(id)
                    .orElseThrow(() -> new RuntimeException("Item not found"));

            if (item.getStatus() != Item.ItemStatus.AVAILABLE) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Item is not available"));
            }

            if (item.getSeller() == null || item.getSeller().getId().equals(buyerId)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Cannot reserve your own item"));
            }

            item.setStatus(Item.ItemStatus.RESERVED);
            item.setReservedBy(buyerId);
            Item savedItem = itemService.addItem(item);
            studentRepository.findById(buyerId)
                    .ifPresent(buyer -> notificationEventService.notifyItemReserved(savedItem, buyer));

            return ResponseEntity.ok(Map.of(
                "message", "Item reserved! Contact seller to confirm.",
                "item", savedItem
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{id}/unreserve")
    public ResponseEntity<?> unreserve(@PathVariable Long id) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            Item item = itemService.getItemById(id)
                    .orElseThrow(() -> new RuntimeException("Not found"));
            boolean isSeller = item.getSeller() != null && item.getSeller().getId().equals(userId);
            boolean isReservedBuyer = item.getReservedBy() != null && item.getReservedBy().equals(userId);
            if (!isSeller && !isReservedBuyer) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }

            item.setStatus(Item.ItemStatus.AVAILABLE);
            item.setReservedBy(null);
            item.setReservedByStudent(null);
            itemService.addItem(item);
            return ResponseEntity.ok(Map.of("message", "Reservation cancelled"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{id}/renew")
    public ResponseEntity<?> renewExpiredItem(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            ownershipValidator.validateItemOwnership(userId, id);
            return ResponseEntity.ok(itemService.renewExpiredItem(id));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteItem(@PathVariable Long id, HttpServletRequest request) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            ownershipValidator.validateItemOwnership(userId, id);
            itemService.deleteItem(id);
            return ResponseEntity.ok(Map.of("message", "Item deleted successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.status(403).body(Map.of("error", e.getMessage()));
        }
    }

    private String normalizeSort(String sort) {
        if ("price_low".equalsIgnoreCase(sort)) return "price_asc";
        if ("price_high".equalsIgnoreCase(sort)) return "price_desc";
        return sort;
    }

    private Student resolveViewer(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            return null;
        }
        try {
            return studentRepository.findById(Long.valueOf(userId.toString())).orElse(null);
        } catch (Exception ignored) {
            return null;
        }
    }

    private void validateUpsertRequest(ItemUpsertRequest request) {
        var violations = validator.validate(request);
        if (!violations.isEmpty()) {
            throw new ConstraintViolationException(violations);
        }
    }
}

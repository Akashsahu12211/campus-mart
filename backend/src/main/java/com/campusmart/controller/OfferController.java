package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.Item;
import com.campusmart.model.Offer;
import com.campusmart.model.Student;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.OfferRepository;
import com.campusmart.repository.StudentRepository;
import com.campusmart.service.NotificationEventService;
import com.campusmart.util.OwnershipValidator;
import com.campusmart.util.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/offers")
public class OfferController {

    @Autowired
    private OfferRepository offerRepository;

    @Autowired
    private ItemRepository itemRepository;

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private OwnershipValidator ownershipValidator;

    @Autowired
    private NotificationEventService notificationEventService;

    @Autowired
    private RateLimiter rateLimiter;

    @PostMapping
    public ResponseEntity<?> createOffer(@RequestBody Map<String, Object> request, HttpServletRequest httpRequest) {
        try {
            Long buyerId = SecurityUtils.getCurrentUserId();
            
            // ── Rate limiting per user ──
            if (!rateLimiter.allowCreateOffer(String.valueOf(buyerId))) {
                return ResponseEntity.status(429).body(Map.of(
                        "error", "Too many offers created. Please try again later."
                ));
            }
            
            Long itemId = ((Number) request.get("itemId")).longValue();
            Double offeredPrice = ((Number) request.get("offeredPrice")).doubleValue();
            String note = (String) request.get("note");

            Item item = itemRepository.findById(itemId)
                .orElseThrow(() -> new RuntimeException("Item not found"));
            Student buyer = studentRepository.findById(buyerId)
                .orElseThrow(() -> new RuntimeException("Buyer not found"));

            if (item.getSeller().getId().equals(buyerId)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Cannot make offer on your own item"));
            }

            Offer offer = new Offer();
            offer.setItem(item);
            offer.setBuyer(buyer);
            offer.setOfferedPrice(offeredPrice);
            offer.setNote(note);
            offer.setStatus(Offer.OfferStatus.PENDING);

            Offer saved = offerRepository.save(offer);
            notificationEventService.notifyNewOffer(saved);
            return ResponseEntity.ok(saved);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @GetMapping("/item/{itemId}")
    public ResponseEntity<?> getOffersForItem(@PathVariable Long itemId) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            ownershipValidator.validateItemOwnership(userId, itemId);
            List<Offer> offers = offerRepository.findByItemId(itemId);
            return ResponseEntity.ok(offers);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @GetMapping("/buyer/{buyerId}")
    public ResponseEntity<?> getOffersFromBuyer(@PathVariable Long buyerId) {
        try {
            SecurityUtils.requireCurrentUser(buyerId);
            List<Offer> offers = offerRepository.findByBuyerId(buyerId);
            return ResponseEntity.ok(offers);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @GetMapping("/seller/{sellerId}")
    public ResponseEntity<?> getOffersForSeller(@PathVariable Long sellerId) {
        try {
            SecurityUtils.requireCurrentUser(sellerId);
            List<Offer> offers = offerRepository.findBySellerId(sellerId);
            return ResponseEntity.ok(offers);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @GetMapping("/{offerId}")
    public ResponseEntity<?> getOfferById(@PathVariable Long offerId) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();
            Offer offer = offerRepository.findById(offerId)
                .orElseThrow(() -> new RuntimeException("Offer not found"));

            boolean isBuyer = offer.getBuyer() != null && offer.getBuyer().getId().equals(userId);
            boolean isSeller = offer.getItem() != null
                && offer.getItem().getSeller() != null
                && offer.getItem().getSeller().getId().equals(userId);
            if (!isBuyer && !isSeller) {
                return ResponseEntity.status(403).body(Map.of("error", "Unauthorized"));
            }
            return ResponseEntity.ok(offer);
        } catch (RuntimeException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @PatchMapping("/{offerId}/accept")
    public ResponseEntity<?> acceptOffer(@PathVariable Long offerId, HttpServletRequest httpRequest) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();

            Offer offer = offerRepository.findById(offerId)
                .orElseThrow(() -> new RuntimeException("Offer not found"));

            if (!offer.getItem().getSeller().getId().equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Only seller can accept offers"));
            }

            if (!offer.getStatus().equals(Offer.OfferStatus.PENDING)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Can only accept pending offers"));
            }

            Item item = offer.getItem();
            if (item.getStatus() == Item.ItemStatus.SOLD) {
                return ResponseEntity.badRequest().body(Map.of("error", "Item is already sold"));
            }
            if (item.getReservedBy() != null && !item.getReservedBy().equals(offer.getBuyer().getId())) {
                return ResponseEntity.badRequest().body(Map.of("error", "Item is already reserved for another buyer"));
            }

            offer.setStatus(Offer.OfferStatus.ACCEPTED);
            offer.setUpdatedAt(java.time.LocalDateTime.now());
            Offer updated = offerRepository.save(offer);

            item.setStatus(Item.ItemStatus.RESERVED);
            item.setReservedBy(offer.getBuyer().getId());
            itemRepository.save(item);

            List<Offer> siblingOffers = offerRepository.findByItemIdAndStatus(item.getId(), Offer.OfferStatus.PENDING);
            for (Offer sibling : siblingOffers) {
                if (!sibling.getId().equals(offer.getId())) {
                    sibling.setStatus(Offer.OfferStatus.REJECTED);
                    sibling.setUpdatedAt(java.time.LocalDateTime.now());
                    offerRepository.save(sibling);
                }
            }

            notificationEventService.notifyOfferStatusUpdated(updated);
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }

    @PatchMapping("/{offerId}/reject")
    public ResponseEntity<?> rejectOffer(@PathVariable Long offerId, HttpServletRequest httpRequest) {
        try {
            Long userId = SecurityUtils.getCurrentUserId();

            Offer offer = offerRepository.findById(offerId)
                .orElseThrow(() -> new RuntimeException("Offer not found"));

            if (!offer.getItem().getSeller().getId().equals(userId)) {
                return ResponseEntity.status(403).body(Map.of("error", "Only seller can reject offers"));
            }

            if (!offer.getStatus().equals(Offer.OfferStatus.PENDING)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Can only reject pending offers"));
            }

            offer.setStatus(Offer.OfferStatus.REJECTED);
            offer.setUpdatedAt(java.time.LocalDateTime.now());
            Offer updated = offerRepository.save(offer);
            notificationEventService.notifyOfferStatusUpdated(updated);
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Internal server error"));
        }
    }
}

package com.campusmart.controller;

import com.campusmart.config.SecurityUtils;
import com.campusmart.model.*;
import com.campusmart.repository.TransactionRepository;
import com.campusmart.repository.ItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/transactions")
public class TransactionController {

    @Autowired private TransactionRepository txRepo;
    @Autowired private ItemRepository        itemRepo;

    // Get buying history
    @GetMapping("/bought/{buyerId}")
    public ResponseEntity<?> getBought(@PathVariable Long buyerId) {
        SecurityUtils.requireCurrentUser(buyerId);
        return ResponseEntity.ok(txRepo.findByBuyerIdOrderByCreatedAtDesc(buyerId));
    }

    // Get selling history
    @GetMapping("/sold/{sellerId}")
    public ResponseEntity<?> getSold(@PathVariable Long sellerId) {
        SecurityUtils.requireCurrentUser(sellerId);
        return ResponseEntity.ok(txRepo.findBySellerIdOrderByCreatedAtDesc(sellerId));
    }

    // Create transaction (when item is marked sold)
    @PostMapping
    public ResponseEntity<?> createTransaction(@RequestBody Map<String, Object> body) {
        Long buyerId  = Long.valueOf(body.get("buyerId").toString());
        Long sellerId = SecurityUtils.getCurrentUserId();
        Long itemId   = Long.valueOf(body.get("itemId").toString());

        Item persistedItem = itemRepo.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found"));
        if (persistedItem.getSeller() == null || !persistedItem.getSeller().getId().equals(sellerId)) {
            return ResponseEntity.status(403).body(java.util.Map.of("error", "Unauthorized"));
        }

        Transaction tx = new Transaction();
        Student buyer  = new Student(); buyer.setId(buyerId);   tx.setBuyer(buyer);
        Student seller = new Student(); seller.setId(sellerId); tx.setSeller(seller);
        Item item      = new Item();    item.setId(itemId);     tx.setItem(item);

        // Item ka price set karo
        tx.setAmount(persistedItem.getPrice());

        // Item status update karo
        persistedItem.setStatus(Item.ItemStatus.SOLD);
        itemRepo.save(persistedItem);

        return ResponseEntity.ok(txRepo.save(tx));
    }
}

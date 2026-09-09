package com.campusmart.util;

import com.campusmart.model.Item;
import com.campusmart.model.Student;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.StudentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class OwnershipValidator {
    
    @Autowired
    private ItemRepository itemRepository;
    
    @Autowired
    private StudentRepository studentRepository;
    
    /**
     * Check if user is the owner of an item
     */
    public boolean isItemOwner(Long userId, Long itemId) {
        Item item = itemRepository.findById(itemId).orElse(null);
        if (item == null) return false;
        
        Student seller = item.getSeller();
        if (seller == null) return false;
        
        return seller.getId().equals(userId);
    }
    
    /**
     * Validate that user owns the item. Throws exception if not.
     */
    public void validateItemOwnership(Long userId, Long itemId) {
        if (!isItemOwner(userId, itemId)) {
            throw new RuntimeException("Unauthorized: You are not the owner of this item");
        }
    }
    
    /**
     * Check if user is the owner of a profile
     */
    public boolean isProfileOwner(Long userId, Long profileId) {
        return userId.equals(profileId);
    }
    
    /**
     * Validate that user owns the profile. Throws exception if not.
     */
    public void validateProfileOwnership(Long userId, Long profileId) {
        if (!isProfileOwner(userId, profileId)) {
            throw new RuntimeException("Unauthorized: You can only modify your own profile");
        }
    }
}

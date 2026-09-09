-- ========================================
-- CAMPUS MART - DATA INTEGRITY CLEANUP
-- ========================================
-- Version: 3.0
-- Description: Data cleanup and deduplication

-- Normalize blank phone numbers
UPDATE students
SET phone = NULL
WHERE phone IS NOT NULL AND TRIM(phone) = '';

-- Remove duplicate wishlist entries
DELETE w1
FROM wishlists w1
INNER JOIN wishlists w2
    ON w1.id > w2.id
   AND w1.student_id = w2.student_id
   AND w1.item_id = w2.item_id;

-- Remove duplicate chat rooms  
DELETE cr1
FROM chat_rooms cr1
INNER JOIN chat_rooms cr2
    ON cr1.id > cr2.id
   AND cr1.user1_id = cr2.user1_id
   AND cr1.user2_id = cr2.user2_id
   AND COALESCE(cr1.item_id, 0) = COALESCE(cr2.item_id, 0);

-- Remove duplicate institutions
DELETE i1
FROM institutions i1
INNER JOIN institutions i2
    ON i1.id > i2.id
   AND LOWER(TRIM(i1.name)) = LOWER(TRIM(i2.name))
   AND LOWER(TRIM(i1.city)) = LOWER(TRIM(i2.city));


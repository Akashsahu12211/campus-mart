# Campus Mart V2 - Complete Rating & Review System Documentation

## Project Overview
Campus Mart V2 is a campus-wide marketplace with three components:
- **Backend**: Java Spring Boot REST API (port 8081)
- **Frontend**: React Application (port 3000/3001)
- **Mobile**: No Flutter implementation found (only backend + frontend exist)

---

## 1. BACKEND MODELS

### Review Model
**File**: `backend/src/main/java/com/campusmart/model/Review.java`

```java
@Entity
@Table(name = "reviews")
public class Review {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "reviewer_id", nullable = false)
    private Student reviewer;          // Who wrote the review

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "seller_id", nullable = false)
    private Student seller;            // Who is being reviewed

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id", nullable = false)
    private Item item;                 // Which item is being reviewed

    @Column(nullable = false)
    private Integer rating;            // Rating value

    @Column(columnDefinition = "TEXT")
    private String comment;            // Review text

    @Column(name = "created_at")
    private LocalDateTime createdAt;   // When review was created
}
```

**Key Fields**:
- `id`: Primary key (Auto-increment)
- `reviewer_id`: Foreign key to `students` (who wrote the review)
- `seller_id`: Foreign key to `students` (seller being reviewed)
- `item_id`: Foreign key to `items` (specific item being reviewed)
- `rating`: Integer rating value (1-5 based on UI)
- `comment`: Text review content
- `created_at`: Timestamp

**Relationships**:
- One Reviewer (Student) → Many Reviews
- One Seller (Student) → Many Reviews  
- One Item → Many Reviews

### Student Model (Transient Fields)
**File**: `backend/src/main/java/com/campusmart/model/Student.java`

```java
@Transient
@JsonProperty("averageRating")
private Double averageRating;     // Calculated from reviews

@Transient
@JsonProperty("totalReviews")
private Long totalReviews;        // Count of reviews
```

These are **transient fields** (not stored in DB, calculated at runtime by ItemService).

---

## 2. DATABASE SCHEMA

### Reviews Table (Spring Boot Auto-Generated)
```sql
-- Created by Hibernate from JPA Entity (ddl-auto=update)
CREATE TABLE reviews (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    reviewer_id BIGINT NOT NULL,
    seller_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    rating INT NOT NULL,
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reviewer_id) REFERENCES students(id),
    FOREIGN KEY (seller_id) REFERENCES students(id),
    FOREIGN KEY (item_id) REFERENCES items(id)
);
```

**Indexes** (implicitly on foreign keys):
- reviewer_id
- seller_id
- item_id
- created_at (for sorting)

**Database File**: `database/campus_mart_v2.sql`
- Note: SQL file only has basic schema. Reviews table is created by Spring Boot's `ddl-auto=update`

---

## 3. API ENDPOINTS

### Review Controller
**File**: `backend/src/main/java/com/campusmart/controller/ReviewController.java`

#### Base URL: `/api/reviews`

| Method | Endpoint | Description | Parameters | Response |
|--------|----------|-------------|-----------|----------|
| GET | `/reviews/seller/{sellerId}` | Get all reviews for a seller with stats | `sellerId` (path) | `{ reviews: [], averageRating: 4.5, totalReviews: 10 }` |
| GET | `/reviews/item/{itemId}` | Get all reviews for a specific item | `itemId` (path) | `{ reviews: [...] }` |
| GET | `/reviews/check` | Check if user already reviewed an item | `reviewerId` (query), `itemId` (query) | `{ reviewed: true/false }` |
| POST | `/reviews` | Create new review | Body: `{ reviewerId, sellerId, itemId, rating, comment }` | Review object |
| PUT | `/reviews/{id}` | Update existing review | `id` (path), Body: `{ rating, comment }` | Updated review object |
| DELETE | `/reviews/{id}` | Delete a review | `id` (path) | `{ message: "Deleted" }` |

**CORS**: Enabled for `http://localhost:3000` and `http://localhost:3001`

---

## 4. SERVICES

### ReviewRepository
**File**: `backend/src/main/java/com/campusmart/repository/ReviewRepository.java`

```java
public interface ReviewRepository extends JpaRepository<Review, Long> {
    // Query methods
    List<Review> findBySellerId(Long sellerId);
    List<Review> findByReviewerId(Long reviewerId);
    List<Review> findByItemId(Long itemId);
    boolean existsByReviewerIdAndItemId(Long reviewerId, Long itemId);
    Optional<Review> findByReviewerIdAndItemId(Long reviewerId, Long itemId);

    // Calculation queries
    @Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.seller.id = :sellerId")
    Double getAverageRatingBySellerId(@Param("sellerId") Long sellerId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.seller.id = :sellerId")
    Long countBySellerId(@Param("sellerId") Long sellerId);
}
```

**Methods Available**:
- `findBySellerId()`: Get all reviews for a seller
- `findByReviewerId()`: Get all reviews written by a user
- `findByItemId()`: Get all reviews for an item
- `existsByReviewerIdAndItemId()`: Check if review exists (prevents duplicates)
- `getAverageRatingBySellerId()`: Calculate average rating (SQL AVG function)
- `countBySellerId()`: Count total reviews for a seller

### ItemService (Rating Population)
**File**: `backend/src/main/java/com/campusmart/service/ItemService.java`

```java
// Helper method to populate seller rating info
private void populateSellerRating(Item item) {
    if (item != null && item.getSeller() != null) {
        Double avgRating = reviewRepository.getAverageRatingBySellerId(item.getSeller().getId());
        Long totalReviews = reviewRepository.countBySellerId(item.getSeller().getId());
        item.getSeller().setAverageRating(avgRating != null ? Math.round(avgRating * 10.0) / 10.0 : 0.0);
        item.getSeller().setTotalReviews(totalReviews != null ? totalReviews : 0L);
    }
}

private void populateSellerRatings(List<Item> items) {
    items.forEach(this::populateSellerRating);
}
```

**Called In**:
- `getAllAvailableItems()` - Populates ratings for all items
- `getAllItems()` - Populates ratings
- `getItemById()` - Populates rating for single item
- `getItemsByCategory()` - Populates ratings
- `getItemsBySeller()` - Populates ratings
- `searchItems()` - Populates ratings
- `getRecentItems()` - Populates ratings

---

## 5. CONTROLLERS

### ReviewController
**File**: `backend/src/main/java/com/campusmart/controller/ReviewController.java`

**Endpoints Logic**:

1. **GET `/reviews/seller/{sellerId}`**
   - Fetches all reviews for a seller
   - Calculates averageRating (rounded to 1 decimal)
   - Returns totalReviews count
   - Response includes full Review objects with reviewer/seller/item details

2. **GET `/reviews/item/{itemId}`**
   - Fetches reviews for a specific item
   - Used to show seller's own review about the item

3. **GET `/reviews/check`**
   - Checks if a specific reviewer has already reviewed an item
   - Prevents duplicate reviews
   - Returns boolean `reviewed`

4. **POST `/reviews`**
   - Creates new review
   - Validates: `existsByReviewerIdAndItemId()` check
   - Cannot have duplicate reviewer-item combinations
   - Sets entities by ID only (doesn't fetch full objects)
   - Auto-sets `createdAt` to now

5. **PUT `/reviews/{id}`**
   - Updates rating and comment
   - Only updates those two fields
   - `createdAt` remains unchanged

6. **DELETE `/reviews/{id}`**
   - Soft/hard delete not specified
   - Simply removes review from DB

### StudentController (Stats Calculation)
**File**: `backend/src/main/java/com/campusmart/controller/StudentController.java`

**GET `/api/students/{id}/stats`** - Returns:
```java
Map<String, Object> stats = new HashMap<>();
stats.put("totalListings", itemRepository.countBySellerId(id));
stats.put("soldItems", itemRepository.countBySellerIdAndStatus(id, Item.ItemStatus.SOLD));
stats.put("totalViews", itemRepository.sumViewCountBySellerId(id));
stats.put("wishlistCount", wishlistRepo.countByStudentId(id));
stats.put("avgRating", avgRating == null ? 0.0 : Math.round(avgRating * 10.0) / 10.0);
stats.put("totalReviews", totalReviews);
stats.put("boughtCount", boughtCount);
```

---

## 6. FRONTEND DISPLAY

### API Integration
**File**: `frontend/src/api/api.js`

```javascript
// Get all reviews for a seller (with stats)
export const getSellerReviews = (sellerId) =>
  api.get(`/reviews/seller/${sellerId}`);

// Get reviews for a specific item
export const getItemReviews = (itemId) =>
  api.get(`/reviews/item/${itemId}`);

// Check if user already reviewed
export const checkReview = (reviewerId, itemId) =>
  api.get(`/reviews/check?reviewerId=${reviewerId}&itemId=${itemId}`);

// Create review
export const addReview = (data) =>
  api.post('/reviews', data);

// Update review
export const updateReview = (id, data) =>
  api.put(`/reviews/${id}`, data);

// Delete review
export const deleteReview = (id) =>
  api.delete(`/reviews/${id}`);
```

### ItemCard Component
**File**: `frontend/src/components/ItemCard.js` (Lines 272-290)

Displays seller rating in item card:
```jsx
{item.seller?.averageRating !== undefined && item.seller?.averageRating !== null && (
  <div style={{ fontSize: '0.72rem', color: '#f59e0b', fontWeight: 700, marginTop: '3px' }}>
    ⭐ {item.seller.averageRating}
    {item.seller?.totalReviews > 0 && (
      <span style={{ fontSize: '0.65rem', color: '#5a6285', fontWeight: 500 }}>
        ({item.seller.totalReviews})
      </span>
    )}
  </div>
)}
```

**Display Format**: `⭐ 4.5 (12)` - Shows rating and count

### ItemDetail Page
**File**: `frontend/src/pages/ItemDetail.js` (Lines 12-17, 45-70, 640-750+)

**State Management**:
```javascript
const [reviews, setReviews] = useState({
  reviews: [],
  averageRating: 0,
  totalReviews: 0
});
const [sellerItemReview, setSellerItemReview] = useState(null);
const [newRating, setNewRating] = useState(5);
const [newComment, setNewComment] = useState('');
const [alreadyReviewed, setAlreadyReviewed] = useState(false);
```

**Features**:
1. **Seller Reviews Section** (Line 640+)
   - Shows seller's average rating with star visualization
   - Displays total review count
   - Shows seller's own review about the item (if exists)

2. **Write Review Section** (Lines 680+)
   - **Visibility**: Only shown if:
     - User is logged in
     - User is NOT the seller
     - Item status is 'SOLD'
     - User hasn't already reviewed
   
   - **Rating Input**: 5 interactive stars (click to select)
   - **Comment Input**: Text area for review text
   - **Submit Button**: Creates review via API

3. **Review List** (Lines 750+)
   - Displays all reviews for the seller
   - Shows reviewer name, avatar (first letter), rating stars, comment, date
   - Edit/Delete buttons for user's own reviews
   - Different styling for user's own review

### EditItem Page (Self-Review Feature)
**File**: `frontend/src/pages/EditItem.js` (Lines 3, 21-23, 70+)

**Unique Feature**: Seller can add a review about their OWN item

```javascript
const [sellerReview, setSellerReview] = useState(null);
const [reviewRating, setReviewRating] = useState(5);
const [reviewComment, setReviewComment] = useState('');

// Fetches seller's review for this item
const myReview = reviews.find(r => r.itemId === parseInt(id) && r.reviewer?.id === user?.id);

// Can update or create review when saving item
if (reviewRating > 0 || reviewComment.trim()) {
  if (sellerReview) {
    await updateReview(sellerReview.id, { rating: reviewRating, comment: reviewComment.trim() });
  } else {
    await addReview({
      rating: reviewRating,
      comment: reviewComment.trim(),
      itemId: parseInt(id),
      reviewerId: user.id,
      sellerId: user.id  // Self-review
    });
  }
}
```

**Special Case**: Seller reviews their own item (reviewer_id == seller_id)

### Profile Page
**File**: `frontend/src/pages/Profile.js` (Lines 30-31, 140+)

Displays user stats including ratings:
```javascript
const [stats, setStats] = useState({
  totalListings: 0,
  soldItems: 0,
  wishlistCount: 0,
  totalViews: 0,
  avgRating: 0,        // ← Average rating
  totalReviews: 0,     // ← Total reviews
  boughtCount: 0
});

// Fetched via getStudentStats(user.id)
```

---

## 7. MOBILE DISPLAY

**Status**: ❌ NO FLUTTER MOBILE APPLICATION FOUND

Only backend (Java/Spring) and frontend (React) exist in this project.

---

## 8. CALCULATION METHODS

### Average Rating Calculation
**Location**: Backend `ReviewRepository.java`

```java
@Query("SELECT COALESCE(AVG(r.rating), 0) FROM Review r WHERE r.seller.id = :sellerId")
Double getAverageRatingBySellerId(@Param("sellerId") Long sellerId);
```

- Uses SQL AVG() function
- Returns 0 if no reviews (COALESCE)
- Calculated at query time (not cached)

### Rounding
**Location**: `StudentController.java` (Line 168) and `ItemService.java` (Line 24)

```java
Math.round(avgRating * 10.0) / 10.0  // Round to 1 decimal place
```

Example: 4.567 → 4.6

### Total Reviews Count
**Location**: Backend `ReviewRepository.java`

```java
@Query("SELECT COUNT(r) FROM Review r WHERE r.seller.id = :sellerId")
Long countBySellerId(@Param("sellerId") Long sellerId);
```

---

## 9. RATING TYPES

| Type | Table | Calculated By | Scope |
|------|-------|---------------|-------|
| **Seller Rating** | reviews | `getAverageRatingBySellerId()` | All reviews for a seller |
| **Item Review** | reviews | Reviews for specific item_id | Specific item-seller combo |
| **Self-Review** | reviews | reviewer_id == seller_id | Seller's review of their own item |
| **Buyer Review** | reviews | By purchaser (not enforced yet) | - |

**Special Cases**:
- **Self-Review** (Seller reviews own item): Shown separately in EditItem and ItemDetail
- **Seller Overall Rating**: Aggregate of ALL reviews for that seller (not per-item)
- **Item-Specific Review**: Seller's one review per item (not multiple)

---

## 10. REVIEW FEATURES

### Can Users Add Reviews? ✅ YES
- Only buyers who purchased an item and item is SOLD
- Enforced by `alreadyReviewed` check: `existsByReviewerIdAndItemId()`
- UI shows form only when `item.status === 'SOLD'`

### Can Users Edit Reviews? ✅ YES
- Via `PUT /api/reviews/{id}`
- Only rating and comment fields
- `createdAt` timestamp stays unchanged
- UI shows edit button for user's own reviews

### Can Users Delete Reviews? ✅ YES
- Via `DELETE /api/reviews/{id}`
- With confirmation dialog
- User can delete only their own reviews
- Enforcement: Frontend only (no backend auth check visible)

### Moderation? ❌ NO
- No moderation fields in Review model
- No approval workflow
- No flagging/reporting system
- No content filtering

---

## 11. RATING SCALE

**Scale**: 1-5 stars ⭐

**Initial Value**: 5 (default when user first opens review form)

**UI Elements**:
- Interactive star selector (click star to select rating)
- Displays rating with stars in review list
- Visually shows: `⭐⭐⭐⭐⭐` (filled stars)

**Database Storage**: Integer (1-5)

---

## 12. RELATED FEATURES

### Features that interact with ratings:

1. **Item Search & Filtering**
   - Ratings displayed on item cards
   - Not sortable by rating (no query parameter support)
   - Used for credibility display

2. **Seller Profile Display**
   - Average rating shown in ItemCard
   - Average rating shown in seller info box on ItemDetail
   - Part of seller credibility score

3. **Student Stats**
   - `avgRating` and `totalReviews` in `/api/students/{id}/stats`
   - Displayed on Profile page
   - Contributes to profile completeness

4. **Reservation System**
   - Not directly tied to ratings
   - But seller ratings influence buyer trust

5. **Transaction History**
   - Reviewed items are marked as `SOLD`
   - Review is the transaction feedback mechanism

6. **Wishlist/Save Item**
   - Ratings influence which items buyers save
   - High-rated sellers' items may be preferred

---

## COMPLETE DATA FLOW EXAMPLE

### Scenario: Buyer reviews a seller

1. **Purchase Flow**
   - Buyer purchases item → Transaction created → Item marked SOLD

2. **Review Creation**
   - Buyer navigates to ItemDetail page
   - UI checks: `checkReview(buyerId, itemId)` → returns `reviewed: false`
   - Review form appears (only because item.status === 'SOLD')
   - Buyer selects 5 stars, writes comment
   - Clicks "Submit Review"

3. **Backend Processing**
   ```java
   POST /api/reviews
   {
     "reviewerId": 5,
     "sellerId": 3,
     "itemId": 12,
     "rating": 5,
     "comment": "Great item, fast delivery"
   }
   ```
   - ReviewController checks: `existsByReviewerIdAndItemId(5, 12)` → false (OK)
   - Creates Review entity with createdAt = now
   - Saves to DB

4. **Rating Update**
   - Next time seller's profile is viewed:
   - Frontend: Calls `getSellerReviews(3)`
   - Backend: Queries `getAverageRatingBySellerId(3)` = 4.7
   - Backend: Queries `countBySellerId(3)` = 15
   - Response: `{ reviews: [...], averageRating: 4.7, totalReviews: 15 }`

5. **Display**
   - ItemCard shows: `⭐ 4.7 (15)`
   - ItemDetail shows: large number 4.7 with star visualization
   - Profile page shows: avgRating: 4.7, totalReviews: 15

---

## KEY TECHNICAL NOTES

### Performance Considerations
1. **No Caching**: Ratings recalculated on every request
2. **N+1 Query**: ItemService calls `populateSellerRating()` for each item (could use JOIN)
3. **No Pagination**: All reviews loaded at once (scalability issue with many reviews)

### Security
1. **No Backend Auth**: Frontend checks ownership, but DELETE endpoint doesn't verify
2. **Transient Fields**: `averageRating` and `totalReviews` not persisted (recalculated)
3. **CORS**: Only allows localhost:3000/3001

### Data Constraints
1. **Rating**: Must be Integer (enforced by SQL NOT NULL)
2. **Comment**: Optional (nullable)
3. **Uniqueness**: One review per reviewer-item pair (business logic only)
4. **Relationships**: Cascading not specified (deletion of Student might break reviews)

### Gaps/Issues
1. ❌ No soft-delete for reviews (complaints can't be archived)
2. ❌ No edit history (changes to reviews aren't tracked)
3. ❌ No reply to reviews (seller can't respond)
4. ❌ No review helpfulness voting (can't rank reviews)
5. ❌ No detailed rating breakdown (can't see 1-star vs 5-star split)
6. ❌ No verification (unverified buyers can review)
7. ❌ No comment character limit (could be very long)

---

## FILE LOCATION REFERENCE

| Component | File Path |
|-----------|-----------|
| Review Model | `backend/src/main/java/com/campusmart/model/Review.java` |
| Review Repository | `backend/src/main/java/com/campusmart/repository/ReviewRepository.java` |
| Review Controller | `backend/src/main/java/com/campusmart/controller/ReviewController.java` |
| Student Controller | `backend/src/main/java/com/campusmart/controller/StudentController.java` |
| Item Service | `backend/src/main/java/com/campusmart/service/ItemService.java` |
| Student Model | `backend/src/main/java/com/campusmart/model/Student.java` |
| Item Model | `backend/src/main/java/com/campusmart/model/Item.java` |
| API Functions | `frontend/src/api/api.js` (lines 88-104) |
| ItemCard Display | `frontend/src/components/ItemCard.js` (lines 272-290) |
| ItemDetail Page | `frontend/src/pages/ItemDetail.js` (lines 12-17, 45-750+) |
| EditItem Page | `frontend/src/pages/EditItem.js` (lines 21-23, 70-120) |
| Profile Page | `frontend/src/pages/Profile.js` (lines 30-31, 140+) |
| Database Schema | `database/campus_mart_v2.sql` |

---

## SUMMARY

The Campus Mart V2 rating system is:
- **Simple**: 1-5 star ratings with optional text comments
- **Seller-Centric**: Rates sellers, not individual items (though reviews reference items)
- **Buyer-Only**: Only non-sellers can review
- **Complete**: Full CRUD operations (Create, Read, Update, Delete)
- **Integrated**: Ratings displayed throughout the UI (ItemCard, ItemDetail, Profile)
- **Real-Time**: No caching, always calculated fresh from DB
- **Somewhat Basic**: Lacks moderation, analytics, and advanced features

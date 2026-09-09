package com.campusmart.service;

import com.campusmart.dto.ItemUpsertRequest;
import com.campusmart.model.Category;
import com.campusmart.model.Item;
import com.campusmart.model.Item.ItemCondition;
import com.campusmart.model.Item.ItemStatus;
import com.campusmart.model.Student;
import com.campusmart.repository.CategoryRepository;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.ReviewRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class ItemService {

    private static final int MAX_SEARCH_PAGE_SIZE = 100;

    @Autowired
    private ItemRepository itemRepository;

    @Autowired
    private ReviewRepository reviewRepository;

    @Autowired
    private NotificationEventService notificationEventService;

    @Autowired
    private StudentService studentService;

    @Autowired
    private MonetizationService monetizationService;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private ItemImageStorageService itemImageStorageService;

    public Item addItem(Item item) {
        normalizePhaseThreeMetadata(item);
        return itemRepository.save(item);
    }

    @Transactional
    public Item createItem(ItemUpsertRequest request, Student seller) {
        Item item = new Item();
        item.setSeller(seller);
        item.setReservedBy(null);
        item.setReservedByStudent(null);
        item.setStatus(Item.ItemStatus.AVAILABLE);
        applyUpsertRequest(item, request, List.of());
        return itemRepository.save(item);
    }

    public List<Item> getAllAvailableItems() {
        List<Item> items = itemRepository.findByStatusOrderByCreatedAtDesc(ItemStatus.AVAILABLE);
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public List<Item> getAllItems() {
        List<Item> items = itemRepository.findAll();
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public Optional<Item> getItemById(Long id) {
        Optional<Item> item = itemRepository.findById(id);
        item.ifPresent(found -> {
            itemRepository.incrementViewCount(id);
            found.setViewCount(found.getViewCount() + 1);
            populateSellerRatings(List.of(found));
            applyBoostState(found);
        });
        return item;
    }

    public List<Item> getItemsByCategory(Long categoryId) {
        List<Item> items = itemRepository.findByCategoryIdAndStatus(categoryId, ItemStatus.AVAILABLE);
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public List<Item> getItemsBySeller(Long sellerId) {
        List<Item> items = itemRepository.findBySellerIdOrderByCreatedAtDesc(sellerId);
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public List<Item> searchItems(String query) {
        List<Item> items = itemRepository.findByTitleContainingIgnoreCaseAndStatus(query, ItemStatus.AVAILABLE);
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public List<Item> getRecentItems() {
        List<Item> items = itemRepository.findTop8ByStatusOrderByCreatedAtDesc(ItemStatus.AVAILABLE);
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public void prepareItemsForViewer(List<Item> items, Student viewer) {
        if (items == null) {
            return;
        }
        items.forEach(item -> prepareItemForViewer(item, viewer));
    }

    public void prepareItemForViewer(Item item, Student viewer) {
        if (item == null) {
            return;
        }

        applyBoostState(item);
        if (item.getSeller() != null) {
            studentService.prepareStudentForViewer(item.getSeller(), viewer);
        }
    }

    public Page<Item> searchAvailableItemsPage(
        String q,
        Long categoryId,
        Item.ListingType listingType,
        Boolean donation,
        Double minPrice,
        Double maxPrice,
        String condition,
        Boolean negotiable,
        String hostel,
        String branch,
        String sortBy,
        int page,
        int pageSize,
        Double userLat,
        Double userLng,
        Double radiusKm
    ) {
        BigDecimal min = minPrice != null ? BigDecimal.valueOf(minPrice) : null;
        BigDecimal max = maxPrice != null ? BigDecimal.valueOf(maxPrice) : null;
        Pageable pageable = PageRequest.of(Math.max(page, 0), clampPageSize(pageSize));
        Page<Item> result = itemRepository.searchAvailableItems(
            normalizeFilterText(q),
            categoryId,
            listingType,
            donation,
            min,
            max,
            parseCondition(condition),
            negotiable,
            normalizeFilterText(hostel),
            normalizeFilterText(branch),
            normalizeSort(sortBy),
            userLat,
            userLng,
            radiusKm,
            pageable,
            LocalDateTime.now()
        );
        applyBoostState(result.getContent());
        populateSellerRatings(result.getContent());
        return result;
    }

    public List<Item> filterItems(
        String q,
        Long categoryId,
        Item.ListingType listingType,
        Boolean donation,
        Double minPrice,
        Double maxPrice,
        String condition,
        Boolean negotiable,
        String hostel,
        String branch,
        String sortBy,
        int page,
        int pageSize,
        Double userLat,
        Double userLng,
        Double radiusKm
    ) {
        return searchAvailableItemsPage(
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
            sortBy,
            page,
            pageSize,
            userLat,
            userLng,
            radiusKm
        ).getContent();
    }

    public long countFilteredItems(
        String q,
        Long categoryId,
        Item.ListingType listingType,
        Boolean donation,
        Double minPrice,
        Double maxPrice,
        String condition,
        Boolean negotiable,
        String hostel,
        String branch,
        Double userLat,
        Double userLng,
        Double radiusKm
    ) {
        return searchAvailableItemsPage(
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
            "newest",
            0,
            1,
            userLat,
            userLng,
            radiusKm
        ).getTotalElements();
    }

    public List<Item> getSimilarItems(Long itemId) {
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found!"));
        List<Item> items = new ArrayList<>();

        if (item.getListingType() == Item.ListingType.BOOK &&
                item.getAcademicSubject() != null &&
                !item.getAcademicSubject().isBlank()) {
            items.addAll(itemRepository.findTop8ByListingTypeAndAcademicSubjectIgnoreCaseAndStatusAndIdNotOrderByCreatedAtDesc(
                Item.ListingType.BOOK,
                item.getAcademicSubject().trim(),
                ItemStatus.AVAILABLE,
                itemId
            ));
        }

        if (items.size() < 8 && item.getCategory() != null && item.getCategory().getId() != null) {
            items.addAll(itemRepository.findTop8ByCategoryIdAndStatusAndIdNotOrderByCreatedAtDesc(
                item.getCategory().getId(),
                ItemStatus.AVAILABLE,
                itemId
            ));
        }

        if (items.size() < 8) {
            items.addAll(itemRepository.findTop8ByListingTypeAndStatusAndIdNotOrderByCreatedAtDesc(
                item.getListingType(),
                ItemStatus.AVAILABLE,
                itemId
            ));
        }

        items = items.stream()
            .filter(candidate -> !candidate.getId().equals(itemId))
            .collect(Collectors.toMap(Item::getId, candidate -> candidate, (first, second) -> first))
            .values()
            .stream()
            .limit(8)
            .collect(Collectors.toList());
        applyBoostState(items);
        items.sort(boostedThenNewestComparator());
        populateSellerRatings(items);
        return items;
    }

    public Item markAsSold(Long itemId) {
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found!"));
        item.setStatus(ItemStatus.SOLD);
        return itemRepository.save(item);
    }

    public Item markAsReserved(Long itemId) {
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found!"));
        item.setStatus(ItemStatus.RESERVED);
        return itemRepository.save(item);
    }

    public Item updateItemStatus(Long itemId, ItemStatus status) {
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found!"));
        item.setStatus(status);
        return itemRepository.save(item);
    }

    @Transactional
    public Item updateItem(Long id, ItemUpsertRequest request) {
        Item existing = itemRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Item not found!"));
        applyUpsertRequest(existing, request, existing.getImageUrls());
        return itemRepository.save(existing);
    }

    public void deleteItem(Long id) {
        itemRepository.deleteById(id);
    }

    public List<Item> getReservedItemsByBuyer(Long buyerId) {
        List<Item> items = itemRepository.findReservedItemsByBuyer(ItemStatus.RESERVED, buyerId);
        populateSellerRatings(items);
        return items;
    }

    public List<Item> getReservedItemsBySeller(Long sellerId) {
        List<Item> items = itemRepository.findReservedItemsBySeller(ItemStatus.RESERVED, sellerId);
        populateStudentRatings(
            items.stream()
                .map(Item::getReservedByStudent)
                .filter(student -> student != null)
                .collect(Collectors.toList())
        );
        return items;
    }

    public Page<Item> getItemsPaginated(Pageable pageable) {
        Page<Item> page = itemRepository.findByStatus(ItemStatus.AVAILABLE, pageable);
        applyBoostState(page.getContent());
        populateSellerRatings(page.getContent());
        return page;
    }

    public Item renewExpiredItem(Long itemId) {
        Item item = itemRepository.findById(itemId)
            .orElseThrow(() -> new RuntimeException("Item not found!"));

        if (item.getStatus() != ItemStatus.EXPIRED) {
            throw new RuntimeException("Only expired items can be renewed");
        }

        item.setStatus(ItemStatus.AVAILABLE);
        item.setCreatedAt(LocalDateTime.now());
        item.setReservedBy(null);
        return itemRepository.save(item);
    }

    public void sendExpiryReminders() {
        try {
            LocalDateTime reminderWindowEnd = LocalDateTime.now().minusDays(23);
            LocalDateTime reminderWindowStart = LocalDateTime.now().minusDays(24);

            List<Item> itemsExpiring = itemRepository.findByStatusAndCreatedAtBetweenOrderByCreatedAtAsc(
                ItemStatus.AVAILABLE,
                reminderWindowStart,
                reminderWindowEnd
            );

            for (Item item : itemsExpiring) {
                try {
                    notificationEventService.notifyItemExpiryReminder(item);
                    System.out.println("[EXPIRY] Reminder processed for item: " + item.getTitle());
                } catch (Exception e) {
                    System.err.println("[EXPIRY] Failed to send reminder for item " + item.getId() + ": " + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.err.println("[EXPIRY] Error sending expiry reminders: " + e.getMessage());
            e.printStackTrace();
        }
    }

    public void markExpiredItems() {
        try {
            LocalDateTime thirtyDaysAgo = LocalDateTime.now().minusDays(30);
            List<Item> expiredItems = itemRepository.findByStatusAndCreatedAtBeforeOrderByCreatedAtAsc(
                ItemStatus.AVAILABLE,
                thirtyDaysAgo
            );

            if (expiredItems.isEmpty()) {
                return;
            }

            expiredItems.forEach(item -> item.setStatus(ItemStatus.EXPIRED));
            itemRepository.saveAll(expiredItems);
            System.out.println("[EXPIRY] Items marked as expired: " + expiredItems.size());
        } catch (Exception e) {
            System.err.println("[EXPIRY] Error marking expired items: " + e.getMessage());
        }
    }

    private void populateSellerRatings(List<Item> items) {
        if (items == null || items.isEmpty()) {
            return;
        }

        Map<Long, RatingSummary> summaries = buildRatingSummaryMap(
            items.stream()
                .map(Item::getSeller)
                .filter(seller -> seller != null && seller.getId() != null)
                .map(Student::getId)
                .collect(Collectors.toSet())
        );

        items.forEach(item -> applyRatingSummary(item.getSeller(), summaries));
    }

    private void populateStudentRatings(List<Student> students) {
        if (students == null || students.isEmpty()) {
            return;
        }

        Map<Long, RatingSummary> summaries = buildRatingSummaryMap(
            students.stream()
                .filter(student -> student.getId() != null)
                .map(Student::getId)
                .collect(Collectors.toSet())
        );

        students.forEach(student -> applyRatingSummary(student, summaries));
    }

    private Map<Long, RatingSummary> buildRatingSummaryMap(Set<Long> sellerIds) {
        if (sellerIds == null || sellerIds.isEmpty()) {
            return Map.of();
        }

        Map<Long, RatingSummary> summaries = new HashMap<>();
        for (Object[] row : reviewRepository.getSellerRatingSummaries(sellerIds)) {
            Long sellerId = ((Number) row[0]).longValue();
            double averageRating = row[1] instanceof Number number ? number.doubleValue() : 0.0;
            long totalReviews = row[2] instanceof Number number ? number.longValue() : 0L;
            summaries.put(sellerId, new RatingSummary(roundRating(averageRating), totalReviews));
        }
        return summaries;
    }

    private void applyRatingSummary(Student student, Map<Long, RatingSummary> summaries) {
        if (student == null || student.getId() == null) {
            return;
        }

        RatingSummary summary = summaries.getOrDefault(student.getId(), RatingSummary.EMPTY);
        student.setAverageRating(summary.averageRating());
        student.setTotalReviews(summary.totalReviews());
    }

    private void applyBoostState(List<Item> items) {
        if (items == null) {
            return;
        }
        items.forEach(this::applyBoostState);
    }

    private void applyBoostState(Item item) {
        if (item == null) {
            return;
        }
        item.setBoostActive(monetizationService.isBoostActive(item));
    }

    private Comparator<Item> boostedComparator() {
        return Comparator
            .comparing((Item item) -> !Boolean.TRUE.equals(item.getBoostActive()))
            .thenComparing(
                (Item item) -> item.getBoostedAt() == null ? LocalDateTime.MIN : item.getBoostedAt(),
                Comparator.reverseOrder()
            );
    }

    private Comparator<Item> boostedThenNewestComparator() {
        return boostedComparator().thenComparing(Item::getCreatedAt, Comparator.reverseOrder());
    }

    private int clampPageSize(int pageSize) {
        if (pageSize <= 0) {
            return 20;
        }
        return Math.min(pageSize, MAX_SEARCH_PAGE_SIZE);
    }

    private String normalizeSort(String sortBy) {
        if (sortBy == null || sortBy.isBlank()) {
            return "newest";
        }
        String normalized = sortBy.trim().toLowerCase(Locale.ROOT);
        if ("price_low".equals(normalized)) {
            return "price_asc";
        }
        if ("price_high".equals(normalized)) {
            return "price_desc";
        }
        return normalized;
    }

    private ItemCondition parseCondition(String condition) {
        if (condition == null || condition.isBlank()) {
            return null;
        }

        try {
            return ItemCondition.valueOf(condition.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ignored) {
            return null;
        }
    }

    private String normalizeFilterText(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private void normalizePhaseThreeMetadata(Item item) {
        if (item == null) {
            return;
        }

        if (item.isDonation()) {
            item.setListingType(Item.ListingType.DONATION);
            item.setPrice(BigDecimal.ZERO);
            item.setNegotiable(false);
        } else if (item.getListingType() == null) {
            item.setListingType(Item.ListingType.GENERAL);
        }

        if (!item.isBundle()) {
            item.setBundleSize(null);
        } else if (item.getBundleSize() != null && item.getBundleSize() < 2) {
            item.setBundleSize(2);
        }

        item.setBookAuthor(trimToNull(item.getBookAuthor()));
        item.setBookEdition(trimToNull(item.getBookEdition()));
        item.setAcademicSubject(trimToNull(item.getAcademicSubject()));
        item.setAcademicCourse(trimToNull(item.getAcademicCourse()));
        item.setAcademicLevel(trimToNull(item.getAcademicLevel()));
        item.setBoardOrUniversity(trimToNull(item.getBoardOrUniversity()));
        item.setPublisher(trimToNull(item.getPublisher()));
        item.setIsbn(trimToNull(item.getIsbn()));
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private void applyUpsertRequest(Item item, ItemUpsertRequest request, Collection<String> existingImageUrls) {
        Category category = resolveCategory(request);

        item.setTitle(trimRequired(request.getTitle(), "Title is required"));
        item.setDescription(trimToNull(request.getDescription()));
        item.setPrice(request.getPrice());
        item.setImageUrls(itemImageStorageService.normalizeListingImages(request.getImageUrls(), existingImageUrls));
        item.setCategory(category);
        item.setCondition(request.getCondition());
        item.setNegotiable(Boolean.TRUE.equals(request.getNegotiable()));
        item.setListingType(request.getListingType());
        item.setDonation(Boolean.TRUE.equals(request.getDonation()));
        item.setBundle(Boolean.TRUE.equals(request.getBundle()));
        item.setBundleSize(request.getBundleSize());
        item.setBookAuthor(request.getBookAuthor());
        item.setBookEdition(request.getBookEdition());
        item.setAcademicSubject(request.getAcademicSubject());
        item.setAcademicCourse(request.getAcademicCourse());
        item.setAcademicLevel(request.getAcademicLevel());
        item.setBoardOrUniversity(request.getBoardOrUniversity());
        item.setPublisher(request.getPublisher());
        item.setIsbn(request.getIsbn());
        normalizePhaseThreeMetadata(item);
    }

    private Category resolveCategory(ItemUpsertRequest request) {
        Long categoryId = request.resolveCategoryId();
        if (categoryId == null) {
            throw new IllegalArgumentException("Category is required");
        }
        return categoryRepository.findById(categoryId)
            .orElseThrow(() -> new IllegalArgumentException("Category not found"));
    }

    private String trimRequired(String value, String message) {
        String trimmed = trimToNull(value);
        if (trimmed == null) {
            throw new IllegalArgumentException(message);
        }
        return trimmed;
    }

    private double roundRating(double averageRating) {
        return Math.round(averageRating * 10.0) / 10.0;
    }

    private record RatingSummary(double averageRating, long totalReviews) {
        private static final RatingSummary EMPTY = new RatingSummary(0.0, 0L);
    }
}

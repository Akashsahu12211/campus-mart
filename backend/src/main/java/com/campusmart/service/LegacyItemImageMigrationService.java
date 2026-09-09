package com.campusmart.service;

import com.campusmart.model.Item;
import com.campusmart.repository.ItemRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
public class LegacyItemImageMigrationService {

    private final ItemRepository itemRepository;
    private final PublicAssetStorageService publicAssetStorageService;

    @Value("${app.item-images.max-count:20}")
    private int maxItemImageCount;

    public LegacyItemImageMigrationService(
            ItemRepository itemRepository,
            PublicAssetStorageService publicAssetStorageService
    ) {
        this.itemRepository = itemRepository;
        this.publicAssetStorageService = publicAssetStorageService;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getInlineImageStats() {
        List<Item> items = itemRepository.findItemsWithInlineImages();
        long itemCount = items.size();
        long imageCount = items.stream()
                .map(Item::getImageUrls)
                .filter(urls -> urls != null)
                .flatMap(List::stream)
                .filter(this::isInlineImage)
                .count();

        return Map.of(
                "itemsWithInlineImages", itemCount,
                "inlineImageCount", imageCount
        );
    }

    @Transactional
    public Map<String, Object> migrateInlineImages(Integer limit) {
        List<Item> candidates = itemRepository.findItemsWithInlineImages();
        int maxItems = limit == null || limit <= 0 ? candidates.size() : Math.min(limit, candidates.size());

        int processedItems = 0;
        int migratedImages = 0;
        List<Long> migratedItemIds = new ArrayList<>();

        for (Item item : candidates) {
            if (processedItems >= maxItems) {
                break;
            }
            List<String> imageUrls = item.getImageUrls();
            if (imageUrls == null || imageUrls.isEmpty()) {
                continue;
            }

            boolean changed = false;
            List<String> migrated = new ArrayList<>(imageUrls.size());
            for (String imageUrl : imageUrls) {
                if (!isInlineImage(imageUrl)) {
                    migrated.add(imageUrl);
                    continue;
                }

                InlineImagePayload payload = decodeInlineImage(imageUrl);
                String extension = extensionForMimeType(payload.contentType());
                String fileName = "legacy-item-" + item.getId() + "-" + UUID.randomUUID() + "." + extension;
                String storedUrl = publicAssetStorageService.storeBytes(
                        payload.bytes(),
                        payload.contentType(),
                        "items",
                        fileName
                );
                migrated.add(storedUrl);
                migratedImages++;
                changed = true;
            }

            if (changed) {
                if (migrated.size() > maxItemImageCount) {
                    throw new RuntimeException("Item " + item.getId() + " exceeds maximum item image count after migration");
                }
                item.setImageUrls(migrated);
                itemRepository.save(item);
                migratedItemIds.add(item.getId());
            }

            processedItems++;
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("processedItems", processedItems);
        result.put("migratedImages", migratedImages);
        result.put("migratedItemIds", migratedItemIds);
        result.put("remainingInlineImageItems", getInlineImageStats().get("itemsWithInlineImages"));
        result.put("remainingInlineImageCount", getInlineImageStats().get("inlineImageCount"));
        return result;
    }

    private boolean isInlineImage(String value) {
        return value != null && value.startsWith("data:image/");
    }

    private InlineImagePayload decodeInlineImage(String value) {
        int separatorIndex = value.indexOf(',');
        if (separatorIndex <= 0) {
            throw new RuntimeException("Invalid inline image payload");
        }

        String metadata = value.substring(5, separatorIndex);
        String base64Payload = value.substring(separatorIndex + 1);
        if (!metadata.contains(";base64")) {
            throw new RuntimeException("Unsupported inline image payload");
        }

        String contentType = metadata.substring(0, metadata.indexOf(';')).trim().toLowerCase(Locale.ROOT);
        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(base64Payload);
        } catch (IllegalArgumentException exception) {
            throw new RuntimeException("Could not decode legacy inline image");
        }

        return new InlineImagePayload(contentType, bytes);
    }

    private String extensionForMimeType(String contentType) {
        return switch (contentType) {
            case "image/png" -> "png";
            case "image/jpeg", "image/jpg" -> "jpg";
            case "image/webp" -> "webp";
            default -> throw new RuntimeException("Unsupported legacy image type: " + contentType);
        };
    }

    private record InlineImagePayload(String contentType, byte[] bytes) {
    }
}

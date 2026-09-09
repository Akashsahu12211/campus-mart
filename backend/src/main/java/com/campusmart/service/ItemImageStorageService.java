package com.campusmart.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class ItemImageStorageService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("png", "jpg", "jpeg", "webp");
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
        "image/png",
        "image/jpeg",
        "image/webp"
    );

    @Value("${app.item-images.max-size-bytes:6291456}")
    private long maxItemImageSizeBytes;

    @Value("${app.item-images.max-count:20}")
    private int maxItemImageCount;

    private final PublicAssetStorageService publicAssetStorageService;

    public ItemImageStorageService(PublicAssetStorageService publicAssetStorageService) {
        this.publicAssetStorageService = publicAssetStorageService;
    }

    public String storeItemImage(MultipartFile file, Long userId) {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("Item image is required");
        }
        if (file.getSize() > maxItemImageSizeBytes) {
            throw new RuntimeException("Item image must be 6MB or smaller");
        }

        String originalName = file.getOriginalFilename() == null ? "item-image" : file.getOriginalFilename();
        String extension = getExtension(originalName);
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new RuntimeException("Only PNG, JPG, JPEG, or WEBP item images are allowed");
        }

        String contentType = file.getContentType() == null ? "" : file.getContentType().trim().toLowerCase(Locale.ROOT);
        if (!ALLOWED_CONTENT_TYPES.contains(contentType)) {
            throw new RuntimeException("Unsupported item image type");
        }

        if (!"webp".equals(extension)) {
            validateRasterImage(file);
        }

        String userPrefix = userId == null ? "guest" : "user-" + userId;
        String fileName = userPrefix + "-" + UUID.randomUUID() + "." + extension;
        return publicAssetStorageService.store(file, "items", fileName);
    }

    public List<String> normalizeListingImages(List<String> imageUrls, Collection<String> existingImageUrls) {
        List<String> source = imageUrls == null ? List.of() : imageUrls;
        Set<String> normalized = new LinkedHashSet<>();
        Set<String> existing = existingImageUrls == null ? Set.of() : new LinkedHashSet<>(existingImageUrls);

        for (String candidate : source) {
            String url = normalizeImageUrl(candidate);
            if (url == null) {
                continue;
            }
            if (url.startsWith("data:") && !existing.contains(url)) {
                throw new RuntimeException("Legacy inline images must be re-uploaded before saving this listing");
            }
            if (!isAllowedListingImageUrl(url)) {
                throw new RuntimeException("Invalid item image reference: " + url);
            }
            normalized.add(url);
        }

        if (normalized.size() > maxItemImageCount) {
            throw new RuntimeException("A maximum of " + maxItemImageCount + " item images is allowed");
        }

        return new ArrayList<>(normalized);
    }

    private boolean isAllowedListingImageUrl(String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        if (value.startsWith("data:")) {
            return true;
        }
        if (value.startsWith("/uploads/")) {
            return true;
        }
        String lower = value.toLowerCase(Locale.ROOT);
        return lower.startsWith("http://") || lower.startsWith("https://");
    }

    private String normalizeImageUrl(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String getExtension(String fileName) {
        int index = fileName.lastIndexOf('.');
        if (index < 0 || index == fileName.length() - 1) {
            return "";
        }
        return fileName.substring(index + 1).toLowerCase(Locale.ROOT);
    }

    private void validateRasterImage(MultipartFile file) {
        try (InputStream inputStream = file.getInputStream()) {
            BufferedImage image = ImageIO.read(inputStream);
            if (image == null || image.getWidth() <= 0 || image.getHeight() <= 0) {
                throw new RuntimeException("Uploaded file is not a valid image");
            }
        } catch (IOException e) {
            throw new RuntimeException("Could not validate uploaded item image");
        }
    }
}

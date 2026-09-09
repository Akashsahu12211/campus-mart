package com.campusmart.service;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.util.Set;
import java.util.UUID;

@Service
public class SiteAssetService {

    private static final long MAX_LOGO_SIZE_BYTES = 2L * 1024 * 1024;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("png", "jpg", "jpeg", "webp");
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
        "image/png",
        "image/jpeg",
        "image/webp"
    );

    private final PublicAssetStorageService publicAssetStorageService;

    public SiteAssetService(PublicAssetStorageService publicAssetStorageService) {
        this.publicAssetStorageService = publicAssetStorageService;
    }

    public String storeCartLogo(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("Cart logo image is required");
        }
        if (file.getSize() > MAX_LOGO_SIZE_BYTES) {
            throw new RuntimeException("Cart logo image must be 2MB or smaller");
        }

        String originalName = file.getOriginalFilename() == null ? "logo" : file.getOriginalFilename();
        String extension = getExtension(originalName);
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new RuntimeException("Only PNG, JPG, JPEG, or WEBP images are allowed");
        }

        String contentType = file.getContentType() == null ? "" : file.getContentType().trim().toLowerCase();
        if (!ALLOWED_CONTENT_TYPES.contains(contentType)) {
            throw new RuntimeException("Unsupported cart logo image type");
        }

        if (!"webp".equals(extension)) {
            validateRasterImage(file);
        }

        String fileName = "cart-logo-" + UUID.randomUUID() + "." + extension;
        return publicAssetStorageService.store(file, "site-settings", fileName);
    }

    private String getExtension(String fileName) {
        int index = fileName.lastIndexOf('.');
        if (index < 0 || index == fileName.length() - 1) {
            return "";
        }
        return fileName.substring(index + 1).toLowerCase();
    }

    private void validateRasterImage(MultipartFile file) {
        try (InputStream inputStream = file.getInputStream()) {
            BufferedImage image = ImageIO.read(inputStream);
            if (image == null || image.getWidth() <= 0 || image.getHeight() <= 0) {
                throw new RuntimeException("Uploaded file is not a valid image");
            }
        } catch (IOException e) {
            throw new RuntimeException("Could not validate uploaded image");
        }
    }
}

package com.campusmart.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.S3ClientBuilder;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.nio.file.StandardOpenOption;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

@Service
public class PublicAssetStorageService {

    @Value("${app.storage.mode:local}")
    private String storageMode;

    @Value("${app.uploads.base-dir:uploads}")
    private String uploadsBaseDir;

    @Value("${app.uploads.public-base-url:}")
    private String uploadsPublicBaseUrl;

    @Value("${app.storage.s3.bucket:}")
    private String s3Bucket;

    @Value("${app.storage.s3.region:ap-south-1}")
    private String s3Region;

    @Value("${app.storage.s3.endpoint:}")
    private String s3Endpoint;

    @Value("${app.storage.s3.access-key:}")
    private String s3AccessKey;

    @Value("${app.storage.s3.secret-key:}")
    private String s3SecretKey;

    @Value("${app.storage.s3.public-base-url:}")
    private String s3PublicBaseUrl;

    @Value("${app.storage.s3.key-prefix:}")
    private String s3KeyPrefix;

    @Value("${app.storage.s3.path-style:false}")
    private boolean s3PathStyle;

    private volatile S3Client s3Client;

    public String store(MultipartFile file, String folder, String fileName) {
        if (isS3Mode()) {
            return storeInS3(file, folder, fileName);
        }
        return storeLocally(file, folder, fileName);
    }

    public String storeBytes(byte[] content, String contentType, String folder, String fileName) {
        if (content == null || content.length == 0) {
            throw new RuntimeException("File content is required");
        }
        if (isS3Mode()) {
            return storeBytesInS3(content, contentType, folder, fileName);
        }
        return storeBytesLocally(content, folder, fileName);
    }

    private String storeLocally(MultipartFile file, String folder, String fileName) {
        try {
            Path directory = Paths.get(uploadsBaseDir, folder).toAbsolutePath().normalize();
            Files.createDirectories(directory);

            Path target = directory.resolve(fileName);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return resolveLocalPublicUrl("/uploads/" + folder + "/" + fileName);
        } catch (IOException e) {
            throw new RuntimeException("Could not store uploaded file");
        }
    }

    private String storeBytesLocally(byte[] content, String folder, String fileName) {
        try {
            Path directory = Paths.get(uploadsBaseDir, folder).toAbsolutePath().normalize();
            Files.createDirectories(directory);

            Path target = directory.resolve(fileName);
            Files.write(target, content, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
            return resolveLocalPublicUrl("/uploads/" + folder + "/" + fileName);
        } catch (IOException e) {
            throw new RuntimeException("Could not store generated file");
        }
    }

    private String storeInS3(MultipartFile file, String folder, String fileName) {
        validateS3Config();
        String key = buildS3Key(folder, fileName);
        try {
            PutObjectRequest request = PutObjectRequest.builder()
                .bucket(s3Bucket)
                .key(key)
                .contentType(file.getContentType())
                .build();
            getS3Client().putObject(request, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
            return resolveS3PublicUrl(key);
        } catch (IOException | S3Exception e) {
            throw new RuntimeException("Could not upload file to object storage");
        }
    }

    private String storeBytesInS3(byte[] content, String contentType, String folder, String fileName) {
        validateS3Config();
        String key = buildS3Key(folder, fileName);
        try {
            PutObjectRequest request = PutObjectRequest.builder()
                .bucket(s3Bucket)
                .key(key)
                .contentType(contentType)
                .build();
            getS3Client().putObject(request, RequestBody.fromBytes(content));
            return resolveS3PublicUrl(key);
        } catch (S3Exception e) {
            throw new RuntimeException("Could not upload file to object storage");
        }
    }

    private synchronized S3Client getS3Client() {
        if (s3Client != null) {
            return s3Client;
        }

        S3ClientBuilder builder = S3Client.builder()
            .region(Region.of(s3Region))
            .credentialsProvider(
                StaticCredentialsProvider.create(
                    AwsBasicCredentials.create(s3AccessKey, s3SecretKey)
                )
            )
            .serviceConfiguration(
                S3Configuration.builder()
                    .pathStyleAccessEnabled(s3PathStyle)
                    .build()
            );

        if (hasText(s3Endpoint)) {
            builder.endpointOverride(URI.create(s3Endpoint));
        }

        s3Client = builder.build();
        return s3Client;
    }

    private boolean isS3Mode() {
        return "s3".equalsIgnoreCase(storageMode);
    }

    private void validateS3Config() {
        if (!hasText(s3Bucket) || !hasText(s3AccessKey) || !hasText(s3SecretKey)) {
            throw new RuntimeException("Object storage is enabled but S3 bucket credentials are incomplete");
        }
    }

    private String resolveLocalPublicUrl(String relativePath) {
        if (!hasText(uploadsPublicBaseUrl)) {
            return relativePath;
        }
        return trimTrailingSlash(uploadsPublicBaseUrl) + relativePath;
    }

    private String resolveS3PublicUrl(String key) {
        if (hasText(s3PublicBaseUrl)) {
            return trimTrailingSlash(s3PublicBaseUrl) + "/" + key;
        }

        if (hasText(s3Endpoint)) {
            if (s3PathStyle) {
                return trimTrailingSlash(s3Endpoint) + "/" + s3Bucket + "/" + key;
            }
            return trimTrailingSlash(s3Endpoint) + "/" + key;
        }

        return "https://" + s3Bucket + ".s3." + s3Region + ".amazonaws.com/" + key;
    }

    private String buildS3Key(String folder, String fileName) {
        String prefix = hasText(s3KeyPrefix) ? trimSlashes(s3KeyPrefix) + "/" : "";
        return prefix + trimSlashes(folder) + "/" + fileName;
    }

    private String trimTrailingSlash(String value) {
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }

    private String trimSlashes(String value) {
        String normalized = value;
        while (normalized.startsWith("/")) {
            normalized = normalized.substring(1);
        }
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        return normalized;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}

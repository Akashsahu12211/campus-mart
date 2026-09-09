package com.campusmart.config;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;

public final class SecurityUtils {

    private SecurityUtils() {
    }

    public static AuthenticatedStudent getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new AccessDeniedException("Unauthorized");
        }

        Object principal = authentication.getPrincipal();
        if (principal instanceof AuthenticatedStudent authenticatedStudent) {
            return authenticatedStudent;
        }

        throw new AccessDeniedException("Unauthorized");
    }

    public static Long getCurrentUserId() {
        return getCurrentUser().getId();
    }

    public static Optional<Long> getOptionalCurrentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            return Optional.empty();
        }

        Object principal = authentication.getPrincipal();
        if (principal instanceof AuthenticatedStudent authenticatedStudent) {
            return Optional.of(authenticatedStudent.getId());
        }

        return Optional.empty();
    }

    public static void requireCurrentUser(Long expectedUserId) {
        if (!getCurrentUserId().equals(expectedUserId)) {
            throw new AccessDeniedException("Unauthorized");
        }
    }
}

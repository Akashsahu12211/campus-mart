package com.campusmart.security;

import com.campusmart.config.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@DisplayName("JWT Security Tests")
class JwtSecurityTests {

    private static final Long TEST_USER_ID = 1L;
    private static final String TEST_EMAIL = "test@example.com";

    private JwtUtil jwtUtil;

    @BeforeEach
    void setUp() {
        jwtUtil = new JwtUtil();
        ReflectionTestUtils.setField(jwtUtil, "secret", "01234567890123456789012345678901");
        ReflectionTestUtils.setField(jwtUtil, "expiryMs", 3_600_000L);
        ReflectionTestUtils.invokeMethod(jwtUtil, "init");
    }

    @Test
    @DisplayName("JWT token is generated successfully")
    void testTokenGeneration() {
        String token = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);

        assertNotNull(token, "Token should not be null");
        assertFalse(token.isEmpty(), "Token should not be empty");
        assertTrue(token.contains("."), "Token should be JWT format (contain dots)");
    }

    @Test
    @DisplayName("JWT token can be validated successfully")
    void testTokenValidation() {
        String token = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);

        assertTrue(jwtUtil.validateToken(token), "Generated token should be valid");
    }

    @Test
    @DisplayName("Invalid JWT token is rejected")
    void testInvalidTokenRejection() {
        assertFalse(jwtUtil.validateToken("invalid.jwt.token"), "Invalid token should not be valid");
    }

    @Test
    @DisplayName("JWT token extracts user ID correctly")
    void testExtractUserIdFromToken() {
        String token = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);

        assertEquals(TEST_USER_ID, jwtUtil.getUserIdFromToken(token),
            "Extracted user ID should match original");
    }

    @Test
    @DisplayName("JWT token includes access-token metadata")
    void testTokenMetadata() {
        String token = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL, 2);

        assertEquals("ACCESS", jwtUtil.getTokenType(token));
        assertEquals(2, jwtUtil.getSessionVersionFromToken(token));
    }

    @Test
    @DisplayName("Tampered JWT token is rejected")
    void testTamperedTokenRejection() {
        String token = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);
        String[] parts = token.split("\\.");
        String tamperedSignature = ("A".equals(parts[2].substring(0, 1)) ? "B" : "A") + parts[2].substring(1);
        String tamperedToken = parts[0] + "." + parts[1] + "." + tamperedSignature;

        assertFalse(jwtUtil.validateToken(tamperedToken), "Tampered token should not be valid");
    }

    @Test
    @DisplayName("Different users get different tokens")
    void testDifferentTokensForDifferentUsers() {
        String token1 = jwtUtil.generateToken(1L, "user1@example.com");
        String token2 = jwtUtil.generateToken(2L, "user2@example.com");

        assertNotEquals(token1, token2, "Different users should get different tokens");
    }

    @Test
    @DisplayName("Same user generates different tokens on each call")
    void testTokenUniquenessPerGeneration() {
        String token1 = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);
        String token2 = jwtUtil.generateToken(TEST_USER_ID, TEST_EMAIL);

        assertNotEquals(token1, token2,
            "Multiple calls should generate different tokens");
    }

    @Test
    @DisplayName("Empty token is rejected")
    void testEmptyTokenRejection() {
        assertFalse(jwtUtil.validateToken(""), "Empty token should not be valid");
    }

    @Test
    @DisplayName("Null token is handled gracefully")
    void testNullTokenHandling() {
        assertFalse(jwtUtil.validateToken(null), "Null token should not be valid");
    }
}

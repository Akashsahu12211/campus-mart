package com.campusmart.config;

import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthorizationFilterTest {

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private StudentRepository studentRepository;

    private AuthorizationFilter authorizationFilter;

    @BeforeEach
    void setUp() {
        authorizationFilter = new AuthorizationFilter(jwtUtil, studentRepository);
        SecurityContextHolder.clearContext();
    }

    @Test
    void allowsRequestWithoutTokenAndLeavesSecurityContextEmpty() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/items");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        authorizationFilter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertNotNull(chain.getRequest());
        assertNull(request.getAttribute("userId"));
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    void ignoresInvalidBearerTokenAndContinuesAsAnonymous() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/wishlist/1");
        request.addHeader("Authorization", "Bearer invalid-token");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        when(jwtUtil.validateToken("invalid-token")).thenReturn(false);

        authorizationFilter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertNotNull(chain.getRequest());
        assertNull(request.getAttribute("userId"));
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

    @Test
    void allowsProtectedEndpointWithValidBearerTokenAndSetsUserId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/wishlist/42");
        request.addHeader("Authorization", "Bearer valid-token");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        when(jwtUtil.validateToken("valid-token")).thenReturn(true);
        when(jwtUtil.getTokenType("valid-token")).thenReturn("ACCESS");
        when(jwtUtil.getUserIdFromToken("valid-token")).thenReturn(42L);
        when(jwtUtil.getSessionVersionFromToken("valid-token")).thenReturn(0);

        Student student = new Student();
        student.setId(42L);
        student.setEmail("admin@campusmart.test");
        student.setRole(Student.StudentRole.ADMIN);
        student.setAuthSessionVersion(0);
        student.setIsActive(true);
        student.setIsBanned(false);
        when(studentRepository.findById(42L)).thenReturn(Optional.of(student));

        authorizationFilter.doFilter(request, response, chain);

        assertEquals(200, response.getStatus());
        assertEquals(42L, request.getAttribute("userId"));
        assertNotNull(chain.getRequest());
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertTrue(SecurityContextHolder.getContext().getAuthentication().isAuthenticated());
        verify(jwtUtil).validateToken("valid-token");
        verify(jwtUtil).getUserIdFromToken("valid-token");
    }
}

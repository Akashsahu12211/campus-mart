package com.campusmart.config;

import com.campusmart.model.Student;
import com.campusmart.repository.StudentRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

public class AuthorizationFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final StudentRepository studentRepository;

    public AuthorizationFilter(JwtUtil jwtUtil, StudentRepository studentRepository) {
        this.jwtUtil = jwtUtil;
        this.studentRepository = studentRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        try {
            String token = authHeader.substring(7);
            if (!jwtUtil.validateToken(token)) {
                clearAuthentication();
                filterChain.doFilter(request, response);
                return;
            }
            if (!"ACCESS".equals(jwtUtil.getTokenType(token))) {
                clearAuthentication();
                filterChain.doFilter(request, response);
                return;
            }

            Long userId = jwtUtil.getUserIdFromToken(token);
            Student student = studentRepository.findById(userId).orElse(null);
            if (student == null) {
                clearAuthentication();
                filterChain.doFilter(request, response);
                return;
            }
            int currentSessionVersion = student.getAuthSessionVersion() == null ? 0 : student.getAuthSessionVersion();
            if (jwtUtil.getSessionVersionFromToken(token) != currentSessionVersion) {
                clearAuthentication();
                filterChain.doFilter(request, response);
                return;
            }
            if (!Boolean.TRUE.equals(student.getIsActive()) || Boolean.TRUE.equals(student.getIsBanned())) {
                clearAuthentication();
                filterChain.doFilter(request, response);
                return;
            }

            AuthenticatedStudent authenticatedStudent = AuthenticatedStudent.from(student);
            UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                    authenticatedStudent,
                    token,
                    authenticatedStudent.getAuthorities()
                );
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(authentication);

            request.setAttribute("userId", authenticatedStudent.getId());
            request.setAttribute("userRole", authenticatedStudent.getRole().name());
            filterChain.doFilter(request, response);
        } catch (Exception e) {
            clearAuthentication();
            filterChain.doFilter(request, response);
        }
    }

    private void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }
}

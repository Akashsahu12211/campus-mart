package com.campusmart.config;

import com.campusmart.repository.StudentRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.logout.LogoutFilter;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;

import java.io.IOException;
import java.util.Map;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtUtil jwtUtil;
    private final StudentRepository studentRepository;
    private final ObjectMapper objectMapper;
    private final SecureTransportEnforcementFilter secureTransportEnforcementFilter;

    public SecurityConfig(
            JwtUtil jwtUtil,
            StudentRepository studentRepository,
            ObjectMapper objectMapper,
            SecureTransportEnforcementFilter secureTransportEnforcementFilter
    ) {
        this.jwtUtil = jwtUtil;
        this.studentRepository = studentRepository;
        this.objectMapper = objectMapper;
        this.secureTransportEnforcementFilter = secureTransportEnforcementFilter;
    }

    @Bean
    public AuthorizationFilter authorizationFilter() {
        return new AuthorizationFilter(jwtUtil, studentRepository);
    }

    @Bean
    public FilterRegistrationBean<AuthorizationFilter> authorizationFilterRegistration(AuthorizationFilter authorizationFilter) {
        FilterRegistrationBean<AuthorizationFilter> registration = new FilterRegistrationBean<>(authorizationFilter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public FilterRegistrationBean<SecureTransportEnforcementFilter> secureTransportFilterRegistration(
            SecureTransportEnforcementFilter secureTransportEnforcementFilter
    ) {
        FilterRegistrationBean<SecureTransportEnforcementFilter> registration =
                new FilterRegistrationBean<>(secureTransportEnforcementFilter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            AuthorizationFilter authorizationFilter,
            org.springframework.beans.factory.ObjectProvider<RateLimitFilter> rateLimitFilterProvider
    )
            throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(Customizer.withDefaults())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .headers(headers -> headers
                .contentTypeOptions(Customizer.withDefaults())
                .frameOptions(frame -> frame.sameOrigin())
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true)
                    .maxAgeInSeconds(31536000))
                .referrerPolicy(referrer -> referrer
                    .policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
            )
            .exceptionHandling(exceptions -> exceptions
                .authenticationEntryPoint((request, response, authException) ->
                    writeJsonError(response, HttpServletResponse.SC_UNAUTHORIZED, "Authentication required"))
                .accessDeniedHandler((request, response, accessDeniedException) ->
                    writeJsonError(response, HttpServletResponse.SC_FORBIDDEN, "Access denied"))
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/error", "/api/auth/**", "/api/public/**", "/uploads/**", "/ws/**").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/payments/webhooks/razorpay").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/support/feedback", "/api/support/report-problem", "/api/support/contact").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/students/login", "/api/students/register").denyAll()
                // ── Public Read Endpoints (no auth required) ──
                .requestMatchers(HttpMethod.GET, "/api/items", "/api/items/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/categories", "/api/categories/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/search/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/reviews/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/monetization/plans").permitAll()
                // ── Admin Endpoints ──
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/categories").hasRole("ADMIN")
                .requestMatchers(HttpMethod.DELETE, "/api/categories/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/payments/*/refund").hasRole("ADMIN")
                .anyRequest().authenticated()
            );
            
            // Rate limiting should run after our JWT auth filter has had a chance to
            // populate request/security context, so authenticated users are keyed by
            // user id instead of falling back to IP address.
            RateLimitFilter rateLimitFilter = rateLimitFilterProvider.getIfAvailable();
            if (rateLimitFilter != null) {
                http.addFilterAfter(rateLimitFilter, UsernamePasswordAuthenticationFilter.class);
            }
            
            http
            .addFilterBefore(secureTransportEnforcementFilter, LogoutFilter.class)
            .addFilterBefore(authorizationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    private void writeJsonError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), Map.of("error", message));
    }
}

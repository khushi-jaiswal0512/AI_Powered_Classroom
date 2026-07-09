/**
 * ============================================================
 * BACKEND FIX REQUIRED — Add this file to your Spring Boot project
 *
 * File location in your Spring Boot project:
 *   src/main/java/com/yourpackage/config/CorsConfig.java
 *
 * This MUST be added to fix CORS for Flutter Web.
 * Without this, the browser blocks ALL API calls from Flutter Web.
 * ============================================================
 */

package com.yourpackage.config;  // ← Change to your actual package name

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();

        // ✅ Allow these origins (add your production Flutter Web URL here)
        config.setAllowedOriginPatterns(List.of(
            "http://localhost:*",       // Flutter Web dev
            "http://127.0.0.1:*",       // Flutter Web dev (alternate)
            "https://*.vercel.app",     // If deployed on Vercel
            "https://*.netlify.app",    // If deployed on Netlify
            "https://*.web.app",        // If deployed on Firebase
            "https://*.firebaseapp.com" // If deployed on Firebase
        ));

        // ✅ Allow all HTTP methods including OPTIONS (preflight)
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));

        // ✅ Allow required headers
        config.setAllowedHeaders(Arrays.asList(
            "Authorization",
            "Content-Type",
            "Accept",
            "Origin",
            "X-Requested-With"
        ));

        // ✅ Expose Authorization header to client
        config.setExposedHeaders(List.of("Authorization"));

        // ✅ Allow cookies / credentials
        config.setAllowCredentials(true);

        // ✅ Cache preflight response for 1 hour (reduces OPTIONS requests)
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);   // Apply to ALL endpoints

        return new CorsFilter(source);
    }
}

/**
 * ============================================================
 * ALSO: If you use Spring Security, add this in SecurityConfig.java
 *
 * In your SecurityFilterChain bean, call .cors(Customizer.withDefaults())
 * BEFORE .csrf(csrf -> csrf.disable()):
 *
 *   http
 *     .cors(Customizer.withDefaults())   // ← Add this line
 *     .csrf(csrf -> csrf.disable())
 *     ...
 *
 * Without this, Spring Security blocks CORS even if CorsConfig is set.
 * ============================================================
 */

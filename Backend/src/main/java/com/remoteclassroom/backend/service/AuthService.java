package com.remoteclassroom.backend.service;

import com.remoteclassroom.backend.model.User;
import com.remoteclassroom.backend.repository.UserRepository;
import com.remoteclassroom.backend.dto.RegisterRequest;
import com.remoteclassroom.backend.dto.LoginRequest;
import com.remoteclassroom.backend.config.JwtUtil;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.HashMap;

@Service
@org.springframework.transaction.annotation.Transactional
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private BCryptPasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtil jwtUtil;

    // REGISTER
    public User register(RegisterRequest request) {
        String email = normalizeEmail(request.getEmail());
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email is already registered. Please login instead.");
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole(request.getRole().toUpperCase());
        user.setPhoneNumber(request.getPhoneNumber());

        return userRepository.save(user);
    }

    // LOGIN
    public Map<String, Object> login(LoginRequest request) {
        String email = normalizeEmail(request.getEmail());
        List<User> users = userRepository.findByEmailOrderByIdDesc(email);

        if (users.isEmpty()) {
            throw new IllegalArgumentException("User not found");
        }

        User user = users.stream()
                .filter(candidate -> candidate.getPassword() != null
                        && request.getPassword() != null
                        && passwordEncoder.matches(request.getPassword(), candidate.getPassword()))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Invalid email or password"));

        if (users.size() > 1) {
            System.err.println("Duplicate users found for email: " + email + ". Login used userId=" + user.getId());
        }

        String role = user.getRole() != null ? user.getRole() : "STUDENT";
        String token = jwtUtil.generateToken(user.getEmail(), role);

        Map<String, Object> response = new HashMap<>();
        response.put("token", token);
        response.put("role", role);
        return response;
    }

    private String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Email is required");
        }
        return email.toLowerCase().trim();
    }
}

package com.remoteclassroom.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.remoteclassroom.backend.model.User;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByEmailOrderByIdDesc(String email);
    boolean existsByEmail(String email);
}

package com.remoteclassroom.backend.controller;

import com.remoteclassroom.backend.dto.QuizDTO;
import com.remoteclassroom.backend.model.Enrollment;
import com.remoteclassroom.backend.model.User;
import com.remoteclassroom.backend.repository.EnrollmentRepository;
import com.remoteclassroom.backend.repository.UserRepository;
import com.remoteclassroom.backend.service.QuizService;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.security.core.Authentication;

@RestController
@RequestMapping("/api/quiz")
public class QuizController {

    @Autowired
    private QuizService quizService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    // ================= GENERATE =================
    @PostMapping("/generate")
    public ResponseEntity<?> generateQuiz(@RequestBody Map<String, Object> request) {

        Number videoIdNum = (Number) request.get("videoId");

        if (videoIdNum == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "videoId is required",
                    "data", null
            ));
        }

        Long videoId = videoIdNum.longValue();

        QuizDTO quiz = quizService.generateAndSaveQuiz(videoId);

        return ResponseEntity.ok(Map.of(
                "success", true,
                "data", quiz
        ));
    }

    // ================= GET BY VIDEO =================
   @GetMapping("/{videoId}")
public ResponseEntity<?> getQuizByVideo(@PathVariable Long videoId, Authentication authentication) {

    if (videoId == null) {
        return ResponseEntity.ok(Map.of(
                "success", false,
                "message", "videoId is required",
                "data", null
        ));
    }

    boolean isStudent = authentication.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_STUDENT"));

    String email = authentication.getName();

    try {

        Optional<QuizDTO> optionalQuiz = quizService.getQuizByVideo(videoId);

        if (optionalQuiz.isEmpty()) {
            return ResponseEntity.ok(Map.of(
                    "success", false,
                    "message", "Quiz not found",
                    "data", null
            ));
        }

        QuizDTO quiz = optionalQuiz.get();

        if (isStudent) {

            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            List<Long> studentBatchIds = enrollmentRepository.findByStudent(user)
                    .stream()
                    .map(e -> {
                        try {
                            return e.getBatch() != null ? e.getBatch().getId() : null;
                        } catch (Exception ex) {
                            return null;
                        }
                    })
                    .filter(id -> id != null)
                    .toList();

            // 🔥 VALIDATION
            if (quiz.getBatchId() == null) {
                return ResponseEntity.ok(Map.of(
                        "success", false,
                        "message", "Quiz not linked to batch",
                        "data", null
                ));
            }

            if (!studentBatchIds.contains(quiz.getBatchId())) {
                return ResponseEntity.status(403).body(Map.of(
                        "success", false,
                        "message", "Access denied",
                        "data", null
                ));
            }

            // 🔥 hide answers
            quiz.setQuestions(scrubAnswers(quiz.getQuestions()));
            quiz.setHierarchy(scrubAnswersFromHierarchy(quiz.getHierarchy()));
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "data", quiz
        ));

    } catch (Exception e) {
        e.printStackTrace();

        // 🔥 DO NOT BREAK API
        return ResponseEntity.ok(Map.of(
                "success", false,
                "message", "Something went wrong",
                "data", null
        ));
    }
}
    // ================= GET BY BATCH =================
    @GetMapping("/batch/{batchId}")
    public ResponseEntity<?> getQuizzesByBatch(@PathVariable Long batchId, Authentication authentication) {

        boolean isStudent = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_STUDENT"));

        String email = authentication.getName();

        List<QuizDTO> quizzes = quizService.getQuizzesByBatch(batchId);

        if (isStudent) {

            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            List<Long> studentBatchIds = enrollmentRepository.findByStudent(user)
                    .stream()
                    .map(e -> e.getBatch().getId())
                    .collect(Collectors.toList());

            // 🔥 filter only allowed batch quizzes
            quizzes = quizzes.stream()
                    .filter(q -> q.getBatchId() != null && studentBatchIds.contains(q.getBatchId()))
                    .collect(Collectors.toList());

            quizzes.forEach(q -> {
                q.setQuestions(scrubAnswers(q.getQuestions()));
                q.setHierarchy(scrubAnswersFromHierarchy(q.getHierarchy()));
            });
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "data", quizzes
        ));
    }

    // ================= SCRUB ANSWERS =================
    private Object scrubAnswers(Object questions) {
        try {
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.JsonNode root = mapper.valueToTree(questions);

            if (root.isArray()) {
                for (com.fasterxml.jackson.databind.JsonNode node : root) {
                    ((com.fasterxml.jackson.databind.node.ObjectNode) node).remove("correctAnswer");
                }
            }

            return root;

        } catch (Exception e) {
            return questions;
        }
    }

    private Object scrubAnswersFromHierarchy(Object hierarchy) {
        try {
            com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
            com.fasterxml.jackson.databind.JsonNode root = mapper.valueToTree(hierarchy);

            if (root.isObject()) {
                root.fields().forEachRemaining(entry -> {
                    if (entry.getValue().isArray()) {
                        for (com.fasterxml.jackson.databind.JsonNode node : entry.getValue()) {
                            if (node.isObject()) {
                                ((com.fasterxml.jackson.databind.node.ObjectNode) node).remove("correctAnswer");
                            }
                        }
                    }
                });
            }

            return root;
        } catch (Exception e) {
            return hierarchy;
        }
    }
}

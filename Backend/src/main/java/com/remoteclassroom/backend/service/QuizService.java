package com.remoteclassroom.backend.service;

import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import com.fasterxml.jackson.core.type.TypeReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.remoteclassroom.backend.dto.QuizDTO;
import com.remoteclassroom.backend.model.Quiz;
import com.remoteclassroom.backend.model.Video;
import com.remoteclassroom.backend.repository.QuizRepository;
import com.remoteclassroom.backend.repository.VideoRepository;

@Service
public class QuizService {

    private static final Logger log = LoggerFactory.getLogger(QuizService.class);

    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private VideoRepository videoRepository;

    @Autowired
    private AIService aiService;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private static final TypeReference<List<Map<String, Object>>> QUESTION_LIST_TYPE = new TypeReference<>() {};
    private static final List<String> LEVEL_ORDER = List.of("EASY", "MEDIUM", "HARD");

    // ================= GENERATE =================
    @Transactional
    public QuizDTO generateAndSaveQuiz(Long videoId) {
        Quiz quiz = getOrGenerateQuiz(videoId, null);
        return mapToDTO(quiz);
    }

    // ================= GET BY VIDEO =================
    @Transactional(readOnly = true)
    public Optional<QuizDTO> getQuizByVideo(Long videoId) {

        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new RuntimeException("Video not found"));

        List<Quiz> quizzes = quizRepository.findByVideoOrderByIdDesc(video);

        if (quizzes == null || quizzes.isEmpty()) {
            log.warn("No quiz found for videoId: {}", videoId);
            return Optional.empty();
        }

        // pick latest valid quiz
        Quiz latestQuiz = quizzes.stream()
                .filter(q -> q.getQuestionsJson() != null && !q.getQuestionsJson().isBlank())
                .findFirst()
                .orElse(quizzes.get(0));

        return Optional.of(mapToDTO(latestQuiz));
    }

    // ================= GET BY BATCH =================
    @Transactional(readOnly = true)
    public List<QuizDTO> getQuizzesByBatch(Long batchId) {
        return quizRepository.findByBatch_Id(batchId).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    // ================= DTO MAPPING =================
    private QuizDTO mapToDTO(Quiz quiz) {

        List<Map<String, Object>> questions = new java.util.ArrayList<>();

        try {
            String json = quiz.getQuestionsJson();

            if (json != null && !json.isBlank()) {

                json = json.trim();

                if (!json.startsWith("[") || !json.endsWith("]")) {
                    log.warn("Invalid JSON format for quiz ID: {}", quiz.getId());
                    json = "[]";
                }

                questions = objectMapper.readValue(json, QUESTION_LIST_TYPE);
            }

        } catch (Exception e) {
            log.error("JSON PARSE FAILED for quiz ID: {}", quiz.getId(), e);
            questions = new java.util.ArrayList<>();
        }

        Long videoId = null;
        Long batchId = null;

        try {
            videoId = (quiz.getVideo() != null) ? quiz.getVideo().getId() : null;
        } catch (Exception e) {
            log.warn("Video lazy load failed for quiz {}", quiz.getId());
        }

        try {
            batchId = (quiz.getBatch() != null) ? quiz.getBatch().getId() : null;
        } catch (Exception e) {
            log.warn("Batch lazy load failed for quiz {}", quiz.getId());
        }

        return new QuizDTO(
                quiz.getId(),
                videoId,
                batchId,
                quiz.getDifficulty(),
                questions,
                buildHierarchy(questions),
                quiz.getTotalQuestions(),
                quiz.getCreatedAt()
        );
    }

    // ================= GENERATE CORE =================
    @Transactional
    public Quiz getOrGenerateQuiz(Long videoId, String studentEmail) {

        log.info("Generating NEW quiz for videoId: {}", videoId);

        Video video = videoRepository.findById(videoId)
                .orElseThrow(() -> new RuntimeException("Video not found"));

        if (video.getBatch() == null) {
            throw new RuntimeException("Video batch missing");
        }

        if (video.getTeacher() == null) {
            throw new RuntimeException("Video teacher missing");
        }

        String transcript = video.getTranscript();

        if (transcript == null || transcript.isBlank()) {
            throw new RuntimeException("Transcript not available");
        }

        String questionsJson = aiService.generateQuiz(transcript, "MIXED", null);

        List<Map<String, Object>> questions = validateQuestions(questionsJson);
        String normalizedQuestionsJson = toJson(questions);

        Quiz quiz = new Quiz();
        quiz.setVideo(video);
        quiz.setTeacher(video.getTeacher());
        quiz.setBatch(video.getBatch());
        quiz.setQuestionsJson(normalizedQuestionsJson);
        quiz.setDifficulty("EASY_MEDIUM_HARD");
        quiz.setTotalQuestions(questions.size());

        return quizRepository.save(quiz);
    }

    public List<Map<String, Object>> validateQuestions(String questionsJson) {
        try {
            if (questionsJson == null || questionsJson.isBlank()) {
                throw new RuntimeException("AI did not return quiz questions");
            }

            String trimmed = questionsJson.trim();
            if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
                throw new RuntimeException("AI returned invalid quiz JSON");
            }

            List<Map<String, Object>> questions = objectMapper.readValue(trimmed, QUESTION_LIST_TYPE);
            List<Map<String, Object>> validQuestions = questions.stream()
                    .map(this::normalizeQuestion)
                    .filter(q -> q.get("question") != null)
                    .filter(q -> q.get("options") instanceof List<?> options && options.size() >= 2)
                    .filter(q -> q.get("correctAnswer") != null)
                    .sorted((left, right) -> Integer.compare(
                            levelRank(String.valueOf(left.get("level"))),
                            levelRank(String.valueOf(right.get("level")))
                    ))
                    .collect(Collectors.toList());

            if (validQuestions.isEmpty()) {
                throw new RuntimeException("AI returned no usable quiz questions");
            }

            return validQuestions;
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("AI returned invalid quiz JSON", e);
        }
    }

    public String normalizeQuestionsJson(String questionsJson) {
        return toJson(validateQuestions(questionsJson));
    }

    private Map<String, Object> normalizeQuestion(Map<String, Object> question) {
        Map<String, Object> normalized = new LinkedHashMap<>(question);

        String level = String.valueOf(normalized.getOrDefault("level", "MEDIUM"))
                .trim()
                .toUpperCase();
        if (!LEVEL_ORDER.contains(level)) {
            level = "MEDIUM";
        }

        String correctAnswer = String.valueOf(normalized.getOrDefault("correctAnswer", ""))
                .trim()
                .toUpperCase()
                .replaceAll("[^A-D]", "");

        normalized.put("level", level);
        normalized.put("correctAnswer", correctAnswer.isBlank() ? null : correctAnswer.substring(0, 1));
        normalized.putIfAbsent("topic", "General");

        return normalized;
    }

    private int levelRank(String level) {
        int index = LEVEL_ORDER.indexOf(level == null ? "" : level.toUpperCase());
        return index >= 0 ? index : 1;
    }

    private Map<String, List<Map<String, Object>>> buildHierarchy(List<Map<String, Object>> questions) {
        Map<String, List<Map<String, Object>>> hierarchy = new LinkedHashMap<>();
        LEVEL_ORDER.forEach(level -> hierarchy.put(level.toLowerCase(), new java.util.ArrayList<>()));

        for (Map<String, Object> question : questions) {
            String level = String.valueOf(question.getOrDefault("level", "MEDIUM")).toUpperCase();
            String key = LEVEL_ORDER.contains(level) ? level.toLowerCase() : "medium";
            hierarchy.get(key).add(question);
        }

        return hierarchy;
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            throw new RuntimeException("Failed to serialize quiz questions", e);
        }
    }
}

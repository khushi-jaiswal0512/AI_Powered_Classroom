package com.remoteclassroom.backend.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.remoteclassroom.backend.dto.QuizAttemptRequest;
import com.remoteclassroom.backend.dto.QuizAttemptResponse;
import com.remoteclassroom.backend.model.Quiz;
import com.remoteclassroom.backend.model.QuizAttempt;
import com.remoteclassroom.backend.model.User;
import com.remoteclassroom.backend.repository.QuizAttemptRepository;
import com.remoteclassroom.backend.repository.QuizRepository;
import com.remoteclassroom.backend.repository.UserRepository;
import com.remoteclassroom.backend.repository.StudentTopicMasteryRepository;
import com.remoteclassroom.backend.model.StudentTopicMastery;

import java.util.Comparator;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;

@Service
public class QuizAttemptService {

    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private QuizAttemptRepository attemptRepository;

    @Autowired
    private StudentTopicMasteryRepository studentTopicMasteryRepository;

    @Autowired
    private UserRepository userRepository;

    private final ObjectMapper mapper = new ObjectMapper();

    @Transactional
    public QuizAttemptResponse submitQuiz(String email, QuizAttemptRequest request) {
        if (request.getQuizId() == null) {
            throw new RuntimeException("quizId is required");
        }

        if (request.getAnswers() == null || request.getAnswers().isEmpty()) {
            throw new RuntimeException("answers are required");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Quiz quiz = quizRepository.findById(request.getQuizId())
                .orElseThrow(() -> new RuntimeException("Quiz not found"));

        List<QuizAttempt> previousAttempts =
                attemptRepository.findByStudent_IdAndQuiz_Id(user.getId(), quiz.getId());

        if (previousAttempts.size() >= 3) {
            throw new RuntimeException("Maximum 3 attempts allowed for this quiz.");
        }

        List<Map<String, Object>> questions = parseQuestions(quiz.getQuestionsJson());
        // 🔥 PREVENT DUPLICATE SUBMISSION
String currentAnswersJson = toJson(request.getAnswers());

List<QuizAttempt> existingAttempts =
        attemptRepository.findByStudent_IdAndQuiz_Id(user.getId(), quiz.getId());

if (!existingAttempts.isEmpty()) {
    QuizAttempt lastAttempt = existingAttempts.get(existingAttempts.size() - 1);

    if (lastAttempt.getAnswersJson() != null &&
        lastAttempt.getAnswersJson().equals(currentAnswersJson)) {

        return new QuizAttemptResponse(
                lastAttempt.getScore(),
                questions.size(),
                new ArrayList<>(), // optional
                getAttemptCount(user.getId(), quiz.getVideo().getId()) >= 3
        );
    }
}

        int score = 0;
        List<String> weakTopicsList = new ArrayList<>();
        Map<String, int[]> topicStats = new HashMap<>();

        for (int i = 0; i < questions.size(); i++) {

            Map<String, Object> q = questions.get(i);

            // 🔥 FIX: normalize correct answer
            String correctRaw = String.valueOf(q.get("correctAnswer"));
            String correct = normalizeAnswer(correctRaw);

            String topic = String.valueOf(q.get("topic"));
            if (topic == null || topic.isBlank()) continue;
            topic = topic.trim();

            // 🔥 FIX: normalize selected answer
            String selectedRaw = request.getAnswers().get(i);
            String selected = normalizeAnswer(selectedRaw);

            boolean isCorrect = selected != null && correct.equals(selected);

            if (isCorrect) {
                score++;
            } else {
                weakTopicsList.add(topic);
            }

            int[] stats = topicStats.getOrDefault(topic, new int[]{0, 0});
            stats[0]++;
            if (isCorrect) stats[1]++;
            topicStats.put(topic, stats);
        }

        weakTopicsList = weakTopicsList.stream().distinct().toList();

        QuizAttempt attempt = new QuizAttempt();
        attempt.setStudent(user);
        attempt.setQuiz(quiz);
        attempt.setAnswersJson(toJson(request.getAnswers()));
        attempt.setScore(score);

        attemptRepository.save(attempt);

        for (Map.Entry<String, int[]> entry : topicStats.entrySet()) {
            String topicName = entry.getKey();
            int attempted = entry.getValue()[0];
            int correctCount = entry.getValue()[1];

            StudentTopicMastery mastery = studentTopicMasteryRepository
                    .findByStudent_IdAndTopicName(user.getId(), topicName)
                    .orElseGet(() -> {
                        StudentTopicMastery m = new StudentTopicMastery();
                        m.setStudent(user);
                        m.setTopicName(topicName);
                        return m;
                    });

            mastery.setTotalAttempted(mastery.getTotalAttempted() + attempted);
            mastery.setCorrectCount(mastery.getCorrectCount() + correctCount);
            mastery.setMasteryLevel(((double) mastery.getCorrectCount() / mastery.getTotalAttempted()) * 100);
            mastery.setLastAttemptDate(LocalDateTime.now());

            studentTopicMasteryRepository.save(mastery);
        }

        int attemptCount = getAttemptCount(user.getId(), quiz.getVideo().getId());
        boolean adaptiveUnlocked = attemptCount >= 3;

        return new QuizAttemptResponse(score, questions.size(), weakTopicsList, adaptiveUnlocked);
    }

    // 🔥 NEW METHOD (ONLY ADDITION)
    private String normalizeAnswer(String answer) {
        if (answer == null) return null;

        answer = answer.trim().toUpperCase();

        // remove unwanted characters
        answer = answer.replaceAll("[^A-D]", "");

        return answer.isEmpty() ? null : answer;
    }

    public int getDistinctQuizCount(Long userId, Long videoId) {

        List<QuizAttempt> attempts =
                attemptRepository.findByStudent_IdAndQuiz_Video_Id(userId, videoId);

        Set<Long> uniqueQuizIds = new HashSet<>();

        for (QuizAttempt a : attempts) {
            if (a.getQuiz() != null) {
                uniqueQuizIds.add(a.getQuiz().getId());
            }
        }

        return uniqueQuizIds.size();
    }

    public int getAttemptCount(Long userId, Long videoId) {
        return attemptRepository.findByStudent_IdAndQuiz_Video_Id(userId, videoId).size();
    }

    public List<QuizAttempt> getAttemptsByVideo(Long userId, Long videoId) {
        return attemptRepository.findByStudent_IdAndQuiz_Video_Id(userId, videoId);
    }

    public String getUserDifficultyAdvanced(Long userId) {

        List<QuizAttempt> attempts = attemptRepository.findByStudent_Id(userId);

        if (attempts.isEmpty()) {
            return "EASY";
        }

        attempts.sort(Comparator.comparing(QuizAttempt::getId));

        double ema = 0.0;
        boolean first = true;
        for (QuizAttempt attempt : attempts) {
            double score = getAttemptPercentage(attempt);
            if (first) {
                ema = score;
                first = false;
            } else {
                ema = (0.7 * score) + (0.3 * ema);
            }
        }

        if (ema >= 80.0) return "HARD";
        else if (ema >= 55.0) return "MEDIUM";
        else return "EASY";
    }

    private double getAttemptPercentage(QuizAttempt attempt) {
        try {
            int totalQuestions = attempt.getQuiz() != null
                    ? attempt.getQuiz().getTotalQuestions()
                    : 0;
            if (totalQuestions <= 0) {
                return attempt.getScore();
            }
            return (attempt.getScore() * 100.0) / totalQuestions;
        } catch (Exception e) {
            return attempt.getScore();
        }
    }

    private List<Map<String, Object>> parseQuestions(String json) {
        try {
            return mapper.readValue(json, new TypeReference<>() {});
        } catch (Exception e) {
            throw new RuntimeException("Error parsing questions JSON", e);
        }
    }

    private String toJson(Object obj) {
        try {
            return mapper.writeValueAsString(obj);
        } catch (Exception e) {
            throw new RuntimeException("JSON conversion error", e);
        }
    }
}

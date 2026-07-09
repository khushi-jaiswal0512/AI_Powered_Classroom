package com.remoteclassroom.backend.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.remoteclassroom.backend.dashboard.dto.response.ProgressTrendResponse;
import com.remoteclassroom.backend.dashboard.dto.response.RecommendationResponse;
import com.remoteclassroom.backend.model.QuizAttempt;
import com.remoteclassroom.backend.model.StudentTopicMastery;
import com.remoteclassroom.backend.repository.QuizAttemptRepository;
import com.remoteclassroom.backend.repository.StudentTopicMasteryRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class RecommendationService {

    private final StudentTopicMasteryRepository masteryRepository;
    private final QuizAttemptRepository quizAttemptRepository;

    public List<RecommendationResponse> getRecommendations(Long studentId) {

        List<StudentTopicMastery> masteries =
                masteryRepository.findByStudent_IdOrderByMasteryLevelAsc(studentId);
        List<QuizAttempt> attempts = quizAttemptRepository.findByStudent_Id(studentId);

        if (masteries == null || masteries.isEmpty()) {
            return List.of(RecommendationResponse.builder()
                    .type("START_LEARNING_PATH")
                    .focus("Take your first quiz")
                    .priority("HIGH")
                    .reason("Complete a quiz so the adaptive system can understand your strengths and weak topics.")
                    .actionLabel("Start with an easy quiz")
                    .masteryLevel(0.0)
                    .build());
        }

        List<RecommendationResponse> recommendations = new ArrayList<>();
        Long recentWeakVideoId = findMostRecentWeakVideoId(attempts);

        for (StudentTopicMastery mastery : masteries) {
            double level = mastery.getMasteryLevel();

            if (level < 40) {
                recommendations.add(RecommendationResponse.builder()
                        .type("RETAKE_QUIZ_STRONG")
                        .focus(mastery.getTopicName())
                        .referenceId(recentWeakVideoId)
                        .priority("HIGH")
                        .reason("Your mastery is below 40%, so this topic should be repaired before moving ahead.")
                        .actionLabel("Retake easy practice")
                        .masteryLevel(round(level))
                        .build());
            } else if (level < 70) {
                recommendations.add(RecommendationResponse.builder()
                        .type("REVISE_TOPIC")
                        .focus(mastery.getTopicName())
                        .referenceId(recentWeakVideoId)
                        .priority("MEDIUM")
                        .reason("You are close, but a short revision pass can stabilize this concept.")
                        .actionLabel("Revise then retry")
                        .masteryLevel(round(level))
                        .build());
            }

            if (recommendations.size() >= 5) {
                break;
            }
        }

        if (recommendations.isEmpty()) {
            StudentTopicMastery strongest = masteries.get(masteries.size() - 1);
            recommendations.add(RecommendationResponse.builder()
                    .type("TAKE_ADVANCED_QUIZ")
                    .focus(strongest.getTopicName())
                    .referenceId(findMostRecentVideoId(attempts))
                    .priority("LOW")
                    .reason("Your recent mastery is strong enough for harder application questions.")
                    .actionLabel("Try hard mode")
                    .masteryLevel(round(strongest.getMasteryLevel()))
                    .build());
        }

        return recommendations;
    }

    public List<ProgressTrendResponse> getOverallTrend(Long studentId) {

        List<QuizAttempt> attempts =
                quizAttemptRepository.findByStudent_Id(studentId);

        if (attempts == null || attempts.isEmpty()) {
            return List.of();
        }

        return attempts.stream()
                .sorted(Comparator.comparing(QuizAttempt::getAttemptedAt,
                        Comparator.nullsLast(Comparator.naturalOrder())))
                .skip(Math.max(0, attempts.size() - 10))
                .map(attempt -> ProgressTrendResponse.builder()
                        .date(attempt.getAttemptedAt() != null
                                ? attempt.getAttemptedAt().toString()
                                : "N/A")
                        .score(toPercentage(attempt))
                        .build())
                .collect(Collectors.toList());
    }

    private Long findMostRecentWeakVideoId(List<QuizAttempt> attempts) {
        if (attempts == null || attempts.isEmpty()) {
            return null;
        }

        return attempts.stream()
                .sorted(Comparator.comparing(QuizAttempt::getAttemptedAt,
                        Comparator.nullsLast(Comparator.naturalOrder())).reversed())
                .filter(attempt -> toPercentage(attempt) < 70)
                .map(this::extractVideoId)
                .filter(id -> id != null)
                .findFirst()
                .orElse(findMostRecentVideoId(attempts));
    }

    private Long findMostRecentVideoId(List<QuizAttempt> attempts) {
        if (attempts == null || attempts.isEmpty()) {
            return null;
        }

        return attempts.stream()
                .sorted(Comparator.comparing(QuizAttempt::getAttemptedAt,
                        Comparator.nullsLast(Comparator.naturalOrder())).reversed())
                .map(this::extractVideoId)
                .filter(id -> id != null)
                .findFirst()
                .orElse(null);
    }

    private Long extractVideoId(QuizAttempt attempt) {
        try {
            return attempt.getQuiz() != null && attempt.getQuiz().getVideo() != null
                    ? attempt.getQuiz().getVideo().getId()
                    : null;
        } catch (Exception e) {
            return null;
        }
    }

    private double toPercentage(QuizAttempt attempt) {
        try {
            int total = attempt.getQuiz() != null ? attempt.getQuiz().getTotalQuestions() : 0;
            if (total <= 0) {
                return attempt.getScore();
            }
            return round((attempt.getScore() * 100.0) / total);
        } catch (Exception e) {
            return attempt.getScore();
        }
    }

    private double round(double value) {
        return Math.round(value * 10.0) / 10.0;
    }
}

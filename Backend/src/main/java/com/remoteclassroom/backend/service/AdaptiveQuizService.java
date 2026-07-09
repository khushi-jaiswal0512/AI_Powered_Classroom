package com.remoteclassroom.backend.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.remoteclassroom.backend.model.Quiz;
import com.remoteclassroom.backend.model.StudentTopicMastery;
import com.remoteclassroom.backend.model.Video;
import com.remoteclassroom.backend.repository.QuizRepository;
import com.remoteclassroom.backend.repository.StudentTopicMasteryRepository;

@Service
@Transactional
public class AdaptiveQuizService {

    @Autowired
    private StudentTopicMasteryRepository studentTopicMasteryRepository;

    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private QuizAttemptService attemptService;

    @Autowired
    private AIService aiService;

    @Autowired
    private QuizService quizService;

    // 🔥 SAFE: avoid null crash
    public int getAttemptCount(Long userId, Long videoId) {
        try {
            return attemptService.getAttemptCount(userId, videoId);
        } catch (Exception e) {
            return 0;
        }
    }

    public Quiz generateAdaptiveQuiz(Long userId, Video video) {

        String difficulty = attemptService.getUserDifficultyAdvanced(userId);

        List<StudentTopicMastery> masteries =
                studentTopicMasteryRepository.findByStudent_IdOrderByMasteryLevelAsc(userId);

        String focusTopic = null;

        if (masteries != null && !masteries.isEmpty()) {
            focusTopic = masteries.get(0).getTopicName();
        }

        String transcript = video.getTranscript();

        if (transcript == null || transcript.isBlank()) {
            throw new RuntimeException("Video has no transcript");
        }

        String questionsJson =
                aiService.generateQuiz(transcript, difficulty, focusTopic);

        List<java.util.Map<String, Object>> questions = quizService.validateQuestions(questionsJson);
        String normalizedQuestionsJson = quizService.normalizeQuestionsJson(questionsJson);
        int totalQuestions = questions.size();

        Quiz quiz = new Quiz();
        quiz.setDifficulty(difficulty);
        quiz.setQuestionsJson(normalizedQuestionsJson);
        quiz.setCreatedAt(LocalDateTime.now());
        quiz.setVideo(video);
        quiz.setBatch(video.getBatch());
        quiz.setTeacher(video.getTeacher());
        quiz.setTotalQuestions(totalQuestions);

        return quizRepository.save(quiz);
    }
}

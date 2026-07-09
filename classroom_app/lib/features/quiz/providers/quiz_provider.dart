import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/quiz_question.dart';
import 'package:classroom_app/data/services/api_service.dart';

final quizProvider = NotifierProvider<QuizNotifier, QuizState>(
  QuizNotifier.new,
);

class QuizState {
  final int? quizId;
  final String? videoId;
  final AsyncValue<List<QuizQuestion>> questions;
  final int currentIndex;
  final int score;
  final int? selectedOptionIndex;
  final bool isCompleted;
  final Map<String, String> userAnswers;
  final List<String> weakTopics;
  final int attempts;
  final bool isLoading;
  final bool isSubmitting;
  final bool isAdaptiveLoading;
  final bool adaptiveUnlocked; // ✅ from backend QuizAttemptResponse.adaptiveUnlocked

  QuizState({
    this.quizId,
    this.videoId,
    required this.questions,
    this.currentIndex = 0,
    this.score = 0,
    this.selectedOptionIndex,
    this.isCompleted = false,
    this.userAnswers = const {},
    this.weakTopics = const [],
    this.attempts = 0,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isAdaptiveLoading = false,
    this.adaptiveUnlocked = false,
  });

  QuizState copyWith({
    int? quizId,
    String? videoId,
    AsyncValue<List<QuizQuestion>>? questions,
    int? currentIndex,
    int? score,
    int? selectedOptionIndex,
    bool? isCompleted,
    bool clearSelection = false,
    Map<String, String>? userAnswers,
    List<String>? weakTopics,
    int? attempts,
    bool? isLoading,
    bool? isSubmitting,
    bool? isAdaptiveLoading,
    bool? adaptiveUnlocked,
  }) {
    return QuizState(
      quizId: quizId ?? this.quizId,
      videoId: videoId ?? this.videoId,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      selectedOptionIndex: clearSelection
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      isCompleted: isCompleted ?? this.isCompleted,
      userAnswers: userAnswers ?? this.userAnswers,
      weakTopics: weakTopics ?? this.weakTopics,
      attempts: attempts ?? this.attempts,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isAdaptiveLoading: isAdaptiveLoading ?? this.isAdaptiveLoading,
      adaptiveUnlocked: adaptiveUnlocked ?? this.adaptiveUnlocked,
    );
  }
}

class QuizNotifier extends Notifier<QuizState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  QuizState build() {
    return QuizState(questions: const AsyncValue.loading());
  }

  Future<void> fetchQuiz(String videoId) async {
    dev.log('Fetching quiz for videoId: $videoId', name: 'QuizProvider');
    state = state.copyWith(
      questions: const AsyncValue.loading(),
      videoId: videoId,
      isLoading: true,
    );

    int maxRetries = 3;
    int retryCount = 0;
    bool has404Retried = false;

    while (retryCount <= maxRetries) {
      try {
        final result = await _apiService.getQuizForVideo(videoId).timeout(const Duration(seconds: 20));

        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];

          // ✅ FIX: quizId=0 causes silent submit failure — throw if missing
          final rawId = (data is Map) ? data['id'] : null;
          if (rawId == null) {
            throw Exception('Quiz response missing ID');
          }
          final int qId = (rawId is int) ? rawId : (rawId as num).toInt();

          List<dynamic> rawData = [];
          if (data is Map && data['questions'] is List) {
            rawData = data['questions'];
          }

          // ✅ Filter out empty questions (AI parse failures return [])
          final mappedData = rawData
              .whereType<Map>()
              .where((e) => e['question'] != null && e['question'].toString().isNotEmpty)
              .map((e) => QuizQuestion(
                    questionText: e['question']?.toString() ?? '',
                    options: (e['options'] is List)
                        ? List<String>.from(e['options'].map((o) => o.toString()))
                        : [],
                    correctAnswer: e['correctAnswer']?.toString() ?? '',
                    topic: e['topic']?.toString() ?? 'General',
                    level: e['level']?.toString().toUpperCase() ?? 'MEDIUM',
                  ))
              .toList();

          final prefs = await SharedPreferences.getInstance();
          final attempts = prefs.getInt(_attemptKey(videoId)) ?? 0;

          dev.log('Quiz fetched successfully. quizId: $qId, questions: ${mappedData.length}', name: 'QuizProvider');
          state = state.copyWith(
            quizId: qId,
            videoId: videoId,
            questions: AsyncValue.data(mappedData),
            currentIndex: 0,
            score: 0,
            clearSelection: true,
            isCompleted: false,
            userAnswers: const {},
            weakTopics: const [],
            isSubmitting: false,
            attempts: attempts,
            isLoading: false,
          );
          return;

        } else {
          final message = result['message'] ?? 'Unknown error';

          // Infer error type from message (statusCode not available in _safeCall response)
          final isNotFound = message.toLowerCase().contains('not found') ||
              message.toLowerCase().contains('404');
          final isServerError = message.toLowerCase().contains('server') ||
              message.toLowerCase().contains('error') ||
              message.toLowerCase().contains('network');

          // 1. Retry once for "not found" (quiz generation might be slow)
          if (isNotFound && !has404Retried) {
            has404Retried = true;
            dev.log('Not found, retrying once...', name: 'QuizProvider');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }

          // 2. Retry up to 3 times for server / network errors
          if (isServerError && retryCount < maxRetries) {
            retryCount++;
            dev.log('Retry $retryCount/$maxRetries for: $message', name: 'QuizProvider');
            await Future.delayed(Duration(seconds: retryCount));
            continue;
          }

          // Final failure
          state = state.copyWith(
            questions: AsyncValue.error(
              Exception(isNotFound ? 'Quiz not available yet.' : message),
              StackTrace.current,
            ),
            isLoading: false,
          );
          return;
        }
      } catch (e, st) {
        if (retryCount < maxRetries) {
          retryCount++;
          int backoff = retryCount;
          dev.log('Exception, retrying $retryCount/$maxRetries: $e');
          await Future.delayed(Duration(seconds: backoff));
          continue;
        }
        state = state.copyWith(
          questions: AsyncValue.error(Exception('Request timed out or failed: $e'), st),
          isLoading: false,
        );
        return;
      }
    }
  }

  void selectOption(int index) {
    if (state.isCompleted || state.isSubmitting) return;
    state = state.copyWith(selectedOptionIndex: index);
  }

  Future<void> submitAnswer() async {
    if (state.isSubmitting) return;

    state.questions.whenData((questions) async {
      if (state.selectedOptionIndex == null) return;

      const letterMap = {0: 'A', 1: 'B', 2: 'C', 3: 'D'};
      final selectedLetter = letterMap[state.selectedOptionIndex] ?? 'A';

      final updatedAnswers = Map<String, String>.from(state.userAnswers);
      updatedAnswers[state.currentIndex.toString()] = selectedLetter;

      if (state.currentIndex < questions.length - 1) {
        state = state.copyWith(
          currentIndex: state.currentIndex + 1,
          clearSelection: true,
          userAnswers: updatedAnswers,
        );
      } else {
        state = state.copyWith(userAnswers: updatedAnswers, isSubmitting: true);
        await _finalizeQuizToBackend(updatedAnswers);
      }
    });
  }

  Future<void> _finalizeQuizToBackend(Map<String, String> finalAnswers) async {
    if (state.quizId == null || state.videoId == null) {
      state = state.copyWith(isSubmitting: false);
      return;
    }

    dev.log('Submitting quiz answers for quizId: ${state.quizId}', name: 'QuizProvider');
    try {
      final response = await _apiService.submitQuizAnswers(
        state.quizId!,
        finalAnswers,
      );

      if (response['success'] != true || response['data'] == null) {
        throw Exception(response['message'] ?? 'Quiz submission failed');
      }

      // ✅ Handle both {data:{score,weakTopics}} and {score,weakTopics} flat shapes
      final rawData = response['data'];
      final Map<String, dynamic> scoreData = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : {};

      // ✅ Safe score parsing (backend may return int or double)
      final score = (scoreData['score'] ?? scoreData['totalScore'] ?? 0);
      final int parsedScore = score is int ? score : (score as num).toInt();

      // ✅ Safe weakTopics parsing — check both top-level and nested
      List<String> weakTopics = [];
      final rawWeak = scoreData['weakTopics']
          ?? scoreData['weakAreas']
          ?? response['weakTopics']
          ?? [];
      if (rawWeak is List) {
        weakTopics = rawWeak.map((e) => e.toString()).toList();
      }

      final prefs = await SharedPreferences.getInstance();
      final key = _attemptKey(state.videoId!);
      int attemptCount = prefs.getInt(key) ?? 0;
      attemptCount++;
      await prefs.setInt(key, attemptCount);

      dev.log('Quiz submitted. Score: $parsedScore, Attempts: $attemptCount, WeakTopics: $weakTopics', name: 'QuizProvider');
      state = state.copyWith(
        score: parsedScore,
        weakTopics: weakTopics,
        isCompleted: true,
        attempts: attemptCount,
        isSubmitting: false,
        // ✅ Use server-side adaptiveUnlocked (QuizAttemptResponse.adaptiveUnlocked)
        // Fallback: local count >= 3 if backend doesn't return this field yet
        adaptiveUnlocked: (scoreData['adaptiveUnlocked'] as bool?) ?? (attemptCount >= 3),
      );
    } catch (e, st) {
      dev.log('Error submitting quiz: $e', name: 'QuizProvider', stackTrace: st);
      state = state.copyWith(
        questions: AsyncValue.error(e, st),
        isSubmitting: false,
      );
    }
  }


  Future<bool> triggerAdaptiveQuiz() async {
    if (state.isAdaptiveLoading || state.videoId == null) return false;

    dev.log('Triggering adaptive quiz for videoId: ${state.videoId}', name: 'QuizProvider');
    state = state.copyWith(isAdaptiveLoading: true);
    try {
      final videoIdInt = int.tryParse(state.videoId!);
      if (videoIdInt == null) {
        state = state.copyWith(isAdaptiveLoading: false);
        return false;
      }
      final previousQuizId = state.quizId;
      final response = await _apiService.generateAdaptiveQuiz(videoIdInt);

      if (response['success'] != true || response['data'] == null) {
        state = state.copyWith(isAdaptiveLoading: false);
        return false;
      }
      
      final data = response['data'];
      final generatedQuizId = data is Map ? data['id'] : null;
      final success = await _pollForQuiz(
        expectedQuizId: generatedQuizId is int
            ? generatedQuizId
            : (generatedQuizId is num ? generatedQuizId.toInt() : null),
        previousQuizId: previousQuizId,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_attemptKey(state.videoId!), 0);
        state = state.copyWith(attempts: 0, isAdaptiveLoading: false);
        return true;
      }
      state = state.copyWith(isAdaptiveLoading: false);
      return false;
    } catch (e, st) {
      dev.log('Error triggering adaptive quiz: $e', name: 'QuizProvider', stackTrace: st);
      state = state.copyWith(isAdaptiveLoading: false);
      return false;
    }
  }

  Future<bool> _pollForQuiz({int? expectedQuizId, int? previousQuizId}) async {
    if (state.videoId == null) return false;

    dev.log('Polling for new quiz...', name: 'QuizProvider');
    for (int i = 0; i < 6; i++) {
      try {
        final result = await _apiService.getQuizForVideo(state.videoId!);
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          final rawId = data is Map ? data['id'] : null;
          final quizId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);

          final isExpectedQuiz = expectedQuizId == null || quizId == expectedQuizId;
          final isNewerQuiz = previousQuizId == null || quizId == null || quizId != previousQuizId;

          if (!isExpectedQuiz || !isNewerQuiz) {
            await Future.delayed(const Duration(milliseconds: 700));
            continue;
          }

          await fetchQuiz(state.videoId!);
          return true;
        }
      } catch (_) {
        // Ignore error and continue polling
      }
      dev.log('Polling attempt ${i + 1}/6...', name: 'QuizProvider');
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }

  void reset() {
    state = QuizState(
      questions: state.questions,
      quizId: state.quizId,
      videoId: state.videoId,
      attempts: state.attempts,
    );
  }

  String _attemptKey(String videoId) => 'quiz_attempts_$videoId';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String videoId;

  const QuizScreen({super.key, required this.videoId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quizProvider.notifier).fetchQuiz(widget.videoId).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Quiz'),
        backgroundColor: Colors.transparent,
        actions: [
          if (quizState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: quizState.questions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final errorStr = error.toString();
          String title = 'Connection Issue';
          String message = 'The server might be waking up. Please try again in a moment.';
          IconData icon = Icons.cloud_off;

          if (errorStr.contains('404')) {
            title = 'Quiz Not Found';
            message = 'A quiz hasn\'t been generated for this video yet. Teachers can generate it from the video card.';
            icon = Icons.quiz_outlined;
          } else if (errorStr.contains('500')) {
            title = 'Server Error';
            message = 'Something went wrong on the server. We\'re looking into it.';
            icon = Icons.dns_outlined;
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 80, color: Colors.orangeAccent.withOpacity(0.8)),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(quizProvider.notifier).fetchQuiz(widget.videoId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
          );
        },
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No quiz questions available for this video.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (quizState.isCompleted) {
            return SingleChildScrollView(
              child: _buildResultScreen(
                context,
                ref,
                quizState.score,
                questions.length,
                quizState.weakTopics,
                quizState.attempts,
              ),
            );
          }

          final currentQuestion = questions[quizState.currentIndex];

          return Column(
            children: [
              if (quizState.isSubmitting)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Question ${quizState.currentIndex + 1} of ${questions.length}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          _LevelChip(level: currentQuestion.level),
                        ],
                      ).animate().fadeIn().slideY(begin: -0.2),

                      const SizedBox(height: 16),

                      Text(
                        currentQuestion.questionText,
                        style: Theme.of(
                          context,
                        ).textTheme.displayMedium?.copyWith(fontSize: 22),
                      ).animate().fadeIn().slideX(),

                      const SizedBox(height: 32),

                      Expanded(
                        child: ListView.builder(
                          itemCount: currentQuestion.options.length,
                          itemBuilder: (context, index) {
                            final isSelected =
                                quizState.selectedOptionIndex == index;
                            return GestureDetector(
                              onTap: () =>
                                  ref
                                      .read(quizProvider.notifier)
                                      .selectOption(index),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.2)
                                      : AppColors.surface,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        currentQuestion.options[index],
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: (100 * index).ms).slideX();
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: quizState.selectedOptionIndex != null &&
                                !quizState.isSubmitting
                            ? () =>
                                ref.read(quizProvider.notifier).submitAnswer()
                            : null,
                        child: quizState.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                quizState.currentIndex == questions.length - 1
                                    ? 'Submit Quiz'
                                    : 'Next Question',
                              ),
                      ).animate().fadeIn().scale(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultScreen(
    BuildContext context,
    WidgetRef ref,
    int score,
    int total,
    List<String> weakTopics,
    int attempts,
  ) {
    final quizState = ref.watch(quizProvider);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events,
            size: 100,
            color: Colors.amber,
          ).animate().scale(duration: 600.ms, curve: Curves.bounceOut),
          const SizedBox(height: 24),
          Text(
            'Quiz Completed!',
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'You scored $score out of $total',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 24),
          ).animate().fadeIn(delay: 500.ms),
          if (weakTopics.isNotEmpty) ...[
            const SizedBox(height: 40),
            const Text(
              '⚠️ Topics to Review:',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: weakTopics
                  .map(
                    (t) => Chip(
                      label: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: AppColors.error.withOpacity(0.2),
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    ),
                  )
                  .toList(),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: quizState.isAdaptiveLoading
                  ? null
                  : () {
                      ref.read(quizProvider.notifier).reset();
                      context.pop();
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Back to Dashboard',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ).animate().fadeIn(delay: 900.ms),
          // ✅ Use server-side adaptiveUnlocked OR local fallback (attempts >= 3)
          if (quizState.adaptiveUnlocked || attempts >= 3) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                
                onPressed: quizState.isAdaptiveLoading
                    ? null
                    : () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Generating adaptive quiz... this may take a moment.",
                            ),
                          ),
                        );
                        final success = await ref
                            .read(quizProvider.notifier)
                            .triggerAdaptiveQuiz();
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Adaptive quiz ready!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to load adaptive quiz"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: quizState.isAdaptiveLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "🚀 Take Adaptive Quiz",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ).animate().fadeIn(delay: 1100.ms),
            if (quizState.isAdaptiveLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Polling for new quiz...",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String level;

  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final normalized = level.toUpperCase();
    final Color color = switch (normalized) {
      'EASY' => Colors.greenAccent,
      'HARD' => Colors.deepOrangeAccent,
      _ => Colors.amberAccent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

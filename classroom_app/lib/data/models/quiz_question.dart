class QuizQuestion {
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String topic;
  final String level;

  QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.topic,
    this.level = 'MEDIUM',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionText: json['question'] ?? 'Unknown Question',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? 'A',
      topic: json['topic'] ?? 'General',
      level: json['level'] ?? 'MEDIUM',
    );
  }
}

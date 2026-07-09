import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';

// ── Models matching backend DTOs ─────────────────────────────────────────────

/// Matches backend RecommendationResponse: {type, focus}
class RecommendationItem {
  /// "RETAKE_QUIZ_STRONG" | "REVISE_TOPIC" | "TAKE_ADVANCED_QUIZ"
  final String type;

  /// The topic name (e.g. "Arrays", "Recursion")
  final String focus;
  final int? referenceId;
  final String priority;
  final String reason;
  final String actionLabel;
  final double? masteryLevel;

  const RecommendationItem({
    required this.type,
    required this.focus,
    this.referenceId,
    this.priority = 'MEDIUM',
    this.reason = '',
    this.actionLabel = 'Review',
    this.masteryLevel,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      type:  json['type']?.toString()  ?? 'REVISE_TOPIC',
      focus: json['focus']?.toString() ?? 'General',
      referenceId: json['referenceId'] is int
          ? json['referenceId']
          : int.tryParse(json['referenceId']?.toString() ?? ''),
      priority: json['priority']?.toString() ?? 'MEDIUM',
      reason: json['reason']?.toString() ?? '',
      actionLabel: json['actionLabel']?.toString() ?? 'Review',
      masteryLevel: json['masteryLevel'] is num
          ? (json['masteryLevel'] as num).toDouble()
          : double.tryParse(json['masteryLevel']?.toString() ?? ''),
    );
  }

  /// Human-readable label for the type
  String get label {
    switch (type) {
      case 'RETAKE_QUIZ_STRONG':
        return 'Needs urgent review';
      case 'REVISE_TOPIC':
        return 'Revise topic';
      case 'TAKE_ADVANCED_QUIZ':
        return 'Ready for challenge!';
      case 'START_LEARNING_PATH':
        return 'Build your baseline';
      default:
        return 'Review';
    }
  }
}

/// Matches backend ProgressTrendResponse: {date, score}
class TrendPoint {
  final String date;
  final int score;

  const TrendPoint({required this.date, required this.score});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date:  json['date']?.toString() ?? '',
      score: (json['score'] ?? 0) is int
          ? json['score']
          : (json['score'] as num).toInt(),
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches GET /api/recommendation
final recommendationProvider =
    FutureProvider.autoDispose<List<RecommendationItem>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getRecommendations();

  if (res['success'] == true && res['data'] is List) {
    return (res['data'] as List)
        .whereType<Map>()
        .map((e) => RecommendationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return [];
});

/// Fetches GET /api/recommendation/trend
final progressTrendProvider =
    FutureProvider.autoDispose<List<TrendPoint>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.getProgressTrend();

  if (res['success'] == true && res['data'] is List) {
    return (res['data'] as List)
        .whereType<Map>()
        .map((e) => TrendPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return [];
});

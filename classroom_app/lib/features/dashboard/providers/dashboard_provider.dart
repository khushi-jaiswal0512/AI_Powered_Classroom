import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classroom_app/data/services/api_service.dart';

// --- Student Dashboard State ---
class StudentDashboardData {
  final double averageScore;
  final int totalQuizzesTaken;
  final List<String> weakTopics;
  final int totalClasses;
  final int attendedClasses;
  final double attendancePercentage;
  final List<Map<String, dynamic>> recentQuizzes;
  final List<Map<String, dynamic>> recentClasses;
  final List<Map<String, dynamic>> overallTrend;
  final List<String> recommendedActions;
  final List<Map<String, dynamic>> recentVideos;

  StudentDashboardData({
    required this.averageScore,
    required this.totalQuizzesTaken,
    required this.weakTopics,
    required this.totalClasses,
    required this.attendedClasses,
    required this.attendancePercentage,
    required this.recentQuizzes,
    required this.recentClasses,
    required this.overallTrend,
    required this.recommendedActions,
    required this.recentVideos,
  });

  factory StudentDashboardData.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      rawJson = <String, dynamic>{};
    }
    final json = rawJson as Map<String, dynamic>;
    final perf = json['performance'] ?? {};
    final att = json['attendance'] ?? {};

    return StudentDashboardData(
      averageScore: (perf['averageScore'] ?? 0).toDouble(),
      totalQuizzesTaken: perf['totalQuizzesTaken'] ?? 0,
      weakTopics: List<String>.from(json['weakTopics'] ?? []),
      totalClasses: att['totalClasses'] ?? 0,
      attendedClasses: att['attendedClasses'] ?? 0,
      attendancePercentage: (att['attendancePercentage'] ?? 0).toDouble(),
      recentQuizzes: List<Map<String, dynamic>>.from(json['recentQuizzes'] ?? []),
      recentClasses: List<Map<String, dynamic>>.from(json['recentClasses'] ?? []),
      overallTrend: List<Map<String, dynamic>>.from(json['overallTrend'] ?? []),
      recommendedActions: List<String>.from(json['recommendedActions'] ?? []),
      recentVideos: List<Map<String, dynamic>>.from(json['recentVideos'] ?? []),
    );
  }
}

final studentDashboardProvider = FutureProvider<StudentDashboardData>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getStudentDashboard();
  return StudentDashboardData.fromJson(response['data']);
});

// --- Teacher Dashboard State ---
class TeacherDashboardData {
  final int totalClassesCreated;
  final int totalStudents;
  final double averageAttendancePerClass;
  final double averageStudentScore;
  final List<String> mostCommonWeakTopics;
  final List<Map<String, dynamic>> recentClasses;
  final List<Map<String, dynamic>> recentQuizStats;

  TeacherDashboardData({
    required this.totalClassesCreated,
    required this.totalStudents,
    required this.averageAttendancePerClass,
    required this.averageStudentScore,
    required this.mostCommonWeakTopics,
    required this.recentClasses,
    required this.recentQuizStats,
  });

  factory TeacherDashboardData.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      rawJson = <String, dynamic>{};
    }
    final json = rawJson as Map<String, dynamic>;
    return TeacherDashboardData(
      totalClassesCreated: json['totalClassesCreated'] ?? 0,
      totalStudents: json['totalStudents'] ?? 0,
      averageAttendancePerClass: (json['averageAttendancePerClass'] ?? 0).toDouble(),
      averageStudentScore: (json['averageStudentScore'] ?? 0).toDouble(),
      mostCommonWeakTopics: List<String>.from(json['mostCommonWeakTopics'] ?? []),
      recentClasses: List<Map<String, dynamic>>.from(json['recentClasses'] ?? []),
      recentQuizStats: List<Map<String, dynamic>>.from(json['recentQuizStats'] ?? []),
    );
  }
}

final teacherDashboardProvider = FutureProvider<TeacherDashboardData>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.getTeacherDashboard();
  return TeacherDashboardData.fromJson(response['data']);
});


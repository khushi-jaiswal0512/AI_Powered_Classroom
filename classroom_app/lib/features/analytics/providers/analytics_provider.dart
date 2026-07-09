import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/attendance_stats.dart';
import 'package:classroom_app/data/services/api_service.dart';

final analyticsProvider = FutureProvider<AttendanceStats>((ref) async {
  final api = ref.read(apiServiceProvider);
  
  // Mock Delay
  await Future.delayed(const Duration(seconds: 1));

  /* REAL API
  final response = await api.getAttendance('latest_class_id');
  return AttendanceStats(
    totalStudents: response.data['total'],
    attendanceCount: response.data['attended'],
  );
  */

  return AttendanceStats(totalStudents: 120, attendanceCount: 85);
});


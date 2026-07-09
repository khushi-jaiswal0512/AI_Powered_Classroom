class AttendanceStats {
  final int totalStudents;
  final int attendanceCount;

  AttendanceStats({required this.totalStudents, required this.attendanceCount});

  double get attendancePercentage => totalStudents == 0 ? 0 : attendanceCount / totalStudents;
}

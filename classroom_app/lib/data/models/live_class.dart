class LiveClass {
  final String id;
  final String title;
  final String teacherName;
  final bool isLive;
  final int attendanceCount;
  final String? meetingId;

  LiveClass({
    required this.id,
    required this.title,
    required this.teacherName,
    required this.isLive,
    this.attendanceCount = 0,
    this.meetingId,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) {
    return LiveClass(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      teacherName: json['teacherEmail'] ?? json['teacherName'] ?? 'Unknown',
      isLive: json['live'] ?? json['isLive'] ?? false,
      attendanceCount: json['attendanceCount'] ?? 0,
      meetingId: json['meetingId'],
    );
  }
}


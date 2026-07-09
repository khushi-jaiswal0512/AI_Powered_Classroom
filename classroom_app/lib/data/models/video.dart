class Video {
  final String id;
  final String title;
  final String? url;
  final String createdAt;
  final String transcriptionStatus;
  final String? transcript;

  Video({
    required this.id,
    required this.title,
    this.url,
    required this.createdAt,
    this.transcriptionStatus = 'Pending',
    this.transcript,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Video',
      url: json['url'],
      // ✅ FIX: backend VideoDTO serializes 'uploadedAt', not 'createdAt'
      createdAt: json['uploadedAt'] ?? json['createdAt'] ?? '',
      transcriptionStatus: json['transcriptionStatus'] ?? 'Pending',
      transcript: json['transcript'],
    );
  }
}

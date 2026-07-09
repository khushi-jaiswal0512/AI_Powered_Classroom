class Batch {
  final int id;
  final String name;
  final String subject;
  final String batchCode;
  final String teacherName;

  Batch({
    required this.id,
    required this.name,
    required this.subject,
    required this.batchCode,
    required this.teacherName,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subject: json['subject'] ?? '',
      batchCode: json['batchCode'] ?? json['code'] ?? '',
      teacherName: json['teacherName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'batchCode': batchCode,
      'teacherName': teacherName,
    };
  }
}

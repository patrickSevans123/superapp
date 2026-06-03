/// Morning briefing from the AI system.
class BriefingModel {
  final String date;
  final String body;
  final int sizeBytes;

  const BriefingModel({
    required this.date,
    required this.body,
    required this.sizeBytes,
  });

  factory BriefingModel.fromJson(Map<String, dynamic> json) {
    return BriefingModel(
      date: json['date'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => body.isEmpty || sizeBytes == 0;
}

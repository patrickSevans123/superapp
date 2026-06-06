/// Morning briefing from the AI system.
class BriefingModel {
  final String date;
  final String body;

  const BriefingModel({
    required this.date,
    required this.body,
  });

  factory BriefingModel.fromJson(Map<String, dynamic> json) {
    return BriefingModel(
      date: json['date'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  /// A briefing is considered empty only when the body has no content.
  /// (The previous version also required `size_bytes > 0`, but the API
  /// never sends that field — it caused every real briefing to look empty.)
  bool get isEmpty => body.isEmpty;
}

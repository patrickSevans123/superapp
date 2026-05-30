/// Ported from self-trade mobile's models/event_model.dart.
class AppEvent {
  final String id;
  final String type;
  final String title;
  final String body;
  final String severity;
  final String? ticker;
  final String createdAt;

  const AppEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    this.ticker,
    required this.createdAt,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      ticker: json['ticker']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'severity': severity,
        'ticker': ticker,
        'created_at': createdAt,
      };
}

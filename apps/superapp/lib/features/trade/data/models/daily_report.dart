import '../../../../core/network/date_converters.dart';

/// A single end-of-day (or intra-day) trading report produced by the
/// self-trade Go service. The body is markdown.
class DailyReport {
  final String id;
  final DateTime date;
  final String title;
  final String markdownBody;

  const DailyReport({
    required this.id,
    required this.date,
    required this.title,
    required this.markdownBody,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = const FlexibleDateTimeConverter().fromJson(rawDate) ??
          DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return DailyReport(
      id: json['id']?.toString() ?? '',
      date: parsedDate,
      title: json['title']?.toString() ?? '',
      markdownBody: json['markdown_body']?.toString() ??
          json['body']?.toString() ??
          json['markdown']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': const FlexibleDateTimeConverter().toJson(date),
        'title': title,
        'markdown_body': markdownBody,
      };

  /// True when this report's calendar day matches [other] in the
  /// device's local timezone.
  bool sameDayAs(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }
}

/// News article data, ported from self-trade Python `newsletter` sources.
///
/// Supports both bloomberg_technoz (id, title, date, url, content) and
/// bloomberg_english / reuters (title, publish_date, url, content, summary,
/// processed_at / scraped_at) schemas — the API now normalises them into
/// a single shape via DuckDB COALESCE.
class NewsItem {
  final String? id;
  final String title;
  final String? summary;
  final String? content;
  final String date; // display date (raw or YYYY-MM-DD)
  final DateTime? processedAt; // scrape/process timestamp (UTC)
  final String? url;
  final String? source; // bloomberg_english | bloomberg_technoz | reuters
  final String? contentPreview; // short snippet, populated by API

  const NewsItem({
    this.id,
    required this.title,
    this.summary,
    this.content,
    required this.date,
    this.processedAt,
    this.url,
    this.source,
    this.contentPreview,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString();
      return DateTime.tryParse(s);
    }

    // Build a short preview if backend didn't include one
    String? preview = json['content_preview']?.toString();
    if (preview == null || preview.isEmpty) {
      final summary = json['summary']?.toString() ?? '';
      final content = json['content']?.toString() ?? '';
      final src = (summary.isNotEmpty ? summary : content);
      if (src.isNotEmpty) {
        // Trim to ~180 chars on a word boundary
        const max = 180;
        if (src.length <= max) {
          preview = src;
        } else {
          final cut = src.substring(0, max);
          final sp = cut.lastIndexOf(' ');
          preview = (sp > 80 ? cut.substring(0, sp) : cut).trim() + '…';
        }
      }
    }

    return NewsItem(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString(),
      content: json['content']?.toString(),
      date: json['date']?.toString() ?? '',
      processedAt: parseDate(json['processed_at'] ?? json['scraped_at']),
      url: json['url']?.toString(),
      source: json['source']?.toString(),
      contentPreview: preview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'content': content,
        'date': date,
        'processed_at': processedAt?.toIso8601String(),
        'url': url,
        'source': source,
        'content_preview': contentPreview,
      };
}

/// Ported from self-trade mobile's models/news_item.dart.
class NewsItem {
  final String title;
  final String date;
  final String? url;
  final String? source;
  final String? summary;

  const NewsItem({
    required this.title,
    required this.date,
    this.url,
    this.source,
    this.summary,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      url: json['url']?.toString(),
      source: json['source']?.toString(),
      summary: json['summary']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'url': url,
        'source': source,
        'summary': summary,
      };
}

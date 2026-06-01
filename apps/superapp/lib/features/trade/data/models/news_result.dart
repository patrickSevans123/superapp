/// Returned by [TradeApiClient.getNews] — bundles the article list with
/// freshness metadata so the UI can render "Updated 9m ago" without a
/// second round-trip to `/news/status`.
class NewsResult {
  final List items; // List<NewsItem> (avoid import cycle in docs)
  final int count;
  final int? ageSeconds;
  final String? ageLabel; // e.g. "1m0s" / "9m0s" / "12h5m"
  final DateTime? latestFileMtime;
  final int? latestFileSize;

  const NewsResult({
    required this.items,
    required this.count,
    this.ageSeconds,
    this.ageLabel,
    this.latestFileMtime,
    this.latestFileSize,
  });

  /// Treats items older than [thresholdHours] as stale. Defaults to 12h
  /// which matches the backend's default `stale_threshold`.
  bool isStale({int thresholdHours = 12}) {
    if (items.isEmpty) return true;
    final ref = ageSeconds ?? _deriveAgeFromMtime();
    if (ref == null) return true;
    return ref > thresholdHours * 3600;
  }

  int? _deriveAgeFromMtime() {
    final m = latestFileMtime;
    if (m == null) return null;
    return DateTime.now().toUtc().difference(m.toUtc()).inSeconds.abs();
  }
}

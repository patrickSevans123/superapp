import 'source_health.dart';

/// `GET /api/v1/news/status` response.
///
/// Backed by `self-trade/app/internal/handler/news.go:GetNewsStatus`.
class NewsStatus {
  final bool allOk;
  final int total;
  final int healthy;
  final int stale;
  final List<SourceHealth> sources;
  final DateTime? checkedAt;

  const NewsStatus({
    required this.allOk,
    required this.total,
    required this.healthy,
    required this.stale,
    required this.sources,
    this.checkedAt,
  });

  factory NewsStatus.fromJson(Map<String, dynamic> json) {
    final raw = (json['sources'] as List<dynamic>?) ?? const [];
    final sources = raw
        .whereType<Map<String, dynamic>>()
        .map(SourceHealth.fromJson)
        .toList();
    return NewsStatus(
      allOk: json['all_ok'] as bool? ?? (json['healthy'] as bool? ?? true),
      total: (json['total'] as num?)?.toInt() ?? sources.length,
      healthy: (json['healthy_count'] as num?)?.toInt() ??
          sources.where((s) => s.healthy).length,
      stale: (json['stale_count'] as num?)?.toInt() ??
          sources.where((s) => s.stale).length,
      sources: sources,
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'].toString())
          : null,
    );
  }

  /// Friendly summary for banners / status pills.
  String get summary {
    if (sources.isEmpty) return 'No news sources configured';
    if (allOk) return '$healthy/$total sources fresh';
    return '$stale of $total source(s) stale';
  }
}

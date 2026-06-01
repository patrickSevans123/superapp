import 'source_health.dart';

/// `GET /api/v1/scrapers/health` response.
///
/// Aggregated view across all scrapers (news + MSCI + trading plans).
class ScraperHealth {
  final bool allHealthy;
  final int totalCount;
  final int healthyCount;
  final int staleCount;
  final List<SourceHealth> sources;
  final DateTime? checkedAt;

  const ScraperHealth({
    required this.allHealthy,
    required this.totalCount,
    required this.healthyCount,
    required this.staleCount,
    required this.sources,
    this.checkedAt,
  });

  factory ScraperHealth.fromJson(Map<String, dynamic> json) {
    final raw = (json['sources'] as List<dynamic>?) ?? const [];
    final sources = raw
        .whereType<Map<String, dynamic>>()
        .map(SourceHealth.fromJson)
        .toList();
    return ScraperHealth(
      allHealthy: json['all_healthy'] as bool? ?? (json['healthy'] as bool? ?? true),
      totalCount: (json['total_count'] as num?)?.toInt() ?? sources.length,
      healthyCount: (json['healthy_count'] as num?)?.toInt() ??
          sources.where((s) => s.healthy).length,
      staleCount: (json['stale_count'] as num?)?.toInt() ??
          sources.where((s) => s.stale).length,
      sources: sources,
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'].toString())
          : null,
    );
  }

  /// The single "biggest" stale source — what the dashboard banner should
  /// call out. Returns null when everything is healthy.
  SourceHealth? get worstOffender {
    if (allHealthy) return null;
    final stale = sources.where((s) => s.stale).toList();
    if (stale.isEmpty) return null;
    stale.sort((a, b) => (b.ageSeconds ?? 0).compareTo(a.ageSeconds ?? 0));
    return stale.first;
  }
}

/// Per-source news freshness row from `GET /api/v1/news/status` and
/// `GET /api/v1/scrapers/health` (subset).
class SourceHealth {
  final String source;
  final int? ageSeconds;
  final String? ageLabel; // "1m0s" / "9m0s" / "12h5m"
  final bool healthy;
  final bool stale;
  final int? staleThresholdSeconds;
  final String? staleThresholdLabel;
  final int? count;
  final String? latestFile;
  final DateTime? latestFileMtime;
  final int? latestFileSize;
  final String? error;

  const SourceHealth({
    required this.source,
    this.ageSeconds,
    this.ageLabel,
    this.healthy = true,
    this.stale = false,
    this.staleThresholdSeconds,
    this.staleThresholdLabel,
    this.count,
    this.latestFile,
    this.latestFileMtime,
    this.latestFileSize,
    this.error,
  });

  factory SourceHealth.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return SourceHealth(
      source: json['source']?.toString() ?? '',
      ageSeconds: (json['age_seconds'] as num?)?.toInt(),
      ageLabel: json['age']?.toString(),
      healthy: json['healthy'] as bool? ?? !json['stale'],
      stale: json['stale'] as bool? ?? false,
      staleThresholdSeconds:
          (json['stale_threshold_seconds'] as num?)?.toInt() ??
              (json['stale_threshold_sec'] as num?)?.toInt(),
      staleThresholdLabel: json['stale_threshold']?.toString(),
      count: (json['count'] as num?)?.toInt() ??
          (json['source_count'] as num?)?.toInt(),
      latestFile: json['latest_file']?.toString(),
      latestFileMtime: parse(json['latest_file_mtime']),
      latestFileSize:
          (json['latest_file_size'] as num?)?.toInt() ??
              (json['latest_file_size_bytes'] as num?)?.toInt() ??
              (json['latest_size_bytes'] as num?)?.toInt(),
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'age_seconds': ageSeconds,
        'age': ageLabel,
        'healthy': healthy,
        'stale': stale,
        'stale_threshold_seconds': staleThresholdSeconds,
        'stale_threshold': staleThresholdLabel,
        'count': count,
        'latest_file': latestFile,
        'latest_file_mtime': latestFileMtime?.toIso8601String(),
        'latest_file_size': latestFileSize,
        'error': error,
      };
}

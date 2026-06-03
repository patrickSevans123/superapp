/// Strategy performance model for backtest results.
///
/// Represents a single strategy's backtest performance with per-asset breakdown.
class StrategyPerformance {
  final String id;
  final String name;
  final String method;
  final String interval;
  final String startDate;
  final String endDate;
  final int nTickers;
  final List<String> tickers;
  final double avgSharpe;
  final double avgMdd;
  final double avgReturn;
  final Map<String, AssetPerformance> perAsset;

  const StrategyPerformance({
    required this.id,
    required this.name,
    required this.method,
    required this.interval,
    required this.startDate,
    required this.endDate,
    required this.nTickers,
    required this.tickers,
    required this.avgSharpe,
    required this.avgMdd,
    required this.avgReturn,
    required this.perAsset,
  });

  factory StrategyPerformance.fromJson(Map<String, dynamic> json) {
    final perAssetMap = <String, AssetPerformance>{};
    final perAssetJson = json['per_asset'] as Map<String, dynamic>? ?? {};
    for (final entry in perAssetJson.entries) {
      if (entry.value is Map<String, dynamic>) {
        perAssetMap[entry.key] = AssetPerformance.fromJson(entry.value);
      }
    }

    return StrategyPerformance(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      method: json['method'] as String? ?? '',
      interval: json['interval'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      nTickers: (json['n_tickers'] as num?)?.toInt() ?? 0,
      tickers: (json['tickers'] as List<dynamic>?)?.cast<String>() ?? [],
      avgSharpe: (json['avg_sharpe'] as num?)?.toDouble() ?? 0,
      avgMdd: (json['avg_mdd'] as num?)?.toDouble() ?? 0,
      avgReturn: (json['avg_return'] as num?)?.toDouble() ?? 0,
      perAsset: perAssetMap,
    );
  }

  /// Annualized return (assuming daily data).
  double get annualizedReturn => avgReturn;

  /// Sharpe ratio color: green > 1, yellow > 0, red < 0.
  String get sharpeRating {
    if (avgSharpe >= 1.5) return 'Excellent';
    if (avgSharpe >= 1.0) return 'Good';
    if (avgSharpe >= 0.5) return 'Fair';
    return 'Poor';
  }
}

/// Per-asset performance within a strategy.
class AssetPerformance {
  final double sharpe;
  final double mdd;
  final double totalReturn;
  final int nTrades;
  final double exposure;
  final int bars;

  const AssetPerformance({
    required this.sharpe,
    required this.mdd,
    required this.totalReturn,
    required this.nTrades,
    required this.exposure,
    required this.bars,
  });

  factory AssetPerformance.fromJson(Map<String, dynamic> json) {
    return AssetPerformance(
      sharpe: (json['sharpe'] as num?)?.toDouble() ?? 0,
      mdd: (json['mdd'] as num?)?.toDouble() ?? 0,
      totalReturn: (json['total_return'] as num?)?.toDouble() ?? 0,
      nTrades: (json['n_trades'] as num?)?.toInt() ?? 0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      bars: (json['bars'] as num?)?.toInt() ?? 0,
    );
  }
}

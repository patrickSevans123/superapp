/// P3: Portfolio Optimization models.
///
/// Represents mean-variance optimization results including
/// efficient frontier, optimal allocation, and individual asset stats.
class PortfolioOptimizeResponse {
  final PortfolioAllocation optimalPortfolio;
  final PortfolioAllocation minVariancePortfolio;
  final List<EfficientFrontierPoint> efficientFrontier;
  final List<AssetStats> individualAssets;
  final PortfolioMetadata metadata;

  PortfolioOptimizeResponse({
    required this.optimalPortfolio,
    required this.minVariancePortfolio,
    required this.efficientFrontier,
    required this.individualAssets,
    required this.metadata,
  });

  factory PortfolioOptimizeResponse.fromJson(Map<String, dynamic> json) {
    return PortfolioOptimizeResponse(
      optimalPortfolio: PortfolioAllocation.fromJson(json['optimal_portfolio'] ?? {}),
      minVariancePortfolio: PortfolioAllocation.fromJson(json['min_variance_portfolio'] ?? {}),
      efficientFrontier: (json['efficient_frontier'] as List? ?? [])
          .map((p) => EfficientFrontierPoint.fromJson(p))
          .toList(),
      individualAssets: (json['individual_assets'] as List? ?? [])
          .map((a) => AssetStats.fromJson(a))
          .toList(),
      metadata: PortfolioMetadata.fromJson(json['metadata'] ?? {}),
    );
  }
}

class PortfolioAllocation {
  final double ret;
  final double risk;
  final double sharpe;
  final List<AllocationItem> allocations;

  PortfolioAllocation({
    required this.ret,
    required this.risk,
    required this.sharpe,
    required this.allocations,
  });

  factory PortfolioAllocation.fromJson(Map<String, dynamic> json) {
    return PortfolioAllocation(
      ret: (json['return'] ?? 0).toDouble(),
      risk: (json['risk'] ?? 0).toDouble(),
      sharpe: (json['sharpe'] ?? 0).toDouble(),
      allocations: (json['allocations'] as List? ?? [])
          .map((a) => AllocationItem.fromJson(a))
          .toList(),
    );
  }
}

class AllocationItem {
  final String ticker;
  final double weight;

  AllocationItem({required this.ticker, required this.weight});

  factory AllocationItem.fromJson(Map<String, dynamic> json) {
    return AllocationItem(
      ticker: json['ticker'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
    );
  }
}

class EfficientFrontierPoint {
  final double ret;
  final double risk;
  final double sharpe;

  EfficientFrontierPoint({
    required this.ret,
    required this.risk,
    required this.sharpe,
  });

  factory EfficientFrontierPoint.fromJson(Map<String, dynamic> json) {
    return EfficientFrontierPoint(
      ret: (json['return'] ?? 0).toDouble(),
      risk: (json['risk'] ?? 0).toDouble(),
      sharpe: (json['sharpe'] ?? 0).toDouble(),
    );
  }
}

class AssetStats {
  final String ticker;
  final double ret;
  final double risk;
  final double sharpe;

  AssetStats({
    required this.ticker,
    required this.ret,
    required this.risk,
    required this.sharpe,
  });

  factory AssetStats.fromJson(Map<String, dynamic> json) {
    return AssetStats(
      ticker: json['ticker'] ?? '',
      ret: (json['return'] ?? 0).toDouble(),
      risk: (json['risk'] ?? 0).toDouble(),
      sharpe: (json['sharpe'] ?? 0).toDouble(),
    );
  }
}

class PortfolioMetadata {
  final List<String> tickers;
  final int nPortfolios;
  final double riskFreeRate;
  final int dataPoints;
  final int annualization;

  PortfolioMetadata({
    required this.tickers,
    required this.nPortfolios,
    required this.riskFreeRate,
    required this.dataPoints,
    required this.annualization,
  });

  factory PortfolioMetadata.fromJson(Map<String, dynamic> json) {
    return PortfolioMetadata(
      tickers: List<String>.from(json['tickers'] ?? []),
      nPortfolios: json['n_portfolios'] ?? 5000,
      riskFreeRate: (json['risk_free_rate'] ?? 0.06).toDouble(),
      dataPoints: json['data_points'] ?? 0,
      annualization: json['annualization'] ?? 252,
    );
  }
}

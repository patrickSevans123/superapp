/// Factor model for the Factor Lab screen.
///
/// Represents composite factor scores for IDX stocks using
/// FF3 + liquidity methodology.
class FactorScore {
  final String ticker;
  final double size;
  final double value;
  final double liquidity;
  final double momentum;
  final double composite;
  final int rank;

  const FactorScore({
    required this.ticker,
    required this.size,
    required this.value,
    required this.liquidity,
    required this.momentum,
    required this.composite,
    required this.rank,
  });

  factory FactorScore.fromJson(Map<String, dynamic> json) {
    return FactorScore(
      ticker: json['ticker'] as String? ?? '',
      size: (json['size'] as num?)?.toDouble() ?? 0,
      value: (json['value'] as num?)?.toDouble() ?? 0,
      liquidity: (json['liquidity'] as num?)?.toDouble() ?? 0,
      momentum: (json['momentum'] as num?)?.toDouble() ?? 0,
      composite: (json['composite'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }

  /// Factor exposure color: positive = green, negative = red.
  double get sizeNorm => size.clamp(-1.0, 1.0);
  double get valueNorm => value.clamp(-1.0, 1.0);
  double get liquidityNorm => liquidity.clamp(-1.0, 1.0);
  double get momentumNorm => momentum.clamp(-1.0, 1.0);
  double get compositeNorm => composite.clamp(-1.0, 1.0);
}

/// Response from the /api/factors endpoint.
class FactorResponse {
  final List<FactorScore> factors;
  final int count;
  final List<String> factorNames;
  final String methodology;

  const FactorResponse({
    required this.factors,
    required this.count,
    required this.factorNames,
    required this.methodology,
  });

  factory FactorResponse.fromJson(Map<String, dynamic> json) {
    final factorsList = (json['factors'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(FactorScore.fromJson)
            .toList() ??
        [];
    return FactorResponse(
      factors: factorsList,
      count: (json['count'] as num?)?.toInt() ?? 0,
      factorNames: (json['factor_names'] as List<dynamic>?)?.cast<String>() ?? [],
      methodology: json['methodology'] as String? ?? '',
    );
  }
}

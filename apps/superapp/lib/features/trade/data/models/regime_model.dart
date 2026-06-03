/// Market regime states.
enum Regime { bull, choppy, highVolTrend, crisis }

extension RegimeX on Regime {
  String get id => switch (this) {
        Regime.bull => 'BULL',
        Regime.choppy => 'CHOPPY',
        Regime.highVolTrend => 'HIGH_VOL_TREND',
        Regime.crisis => 'CRISIS',
      };

  String get tagline => switch (this) {
        Regime.bull => 'Risk-on tilt • favor momentum & golden-cross',
        Regime.choppy => 'Mean-reversion bias • reduce gross',
        Regime.highVolTrend => 'Trend with wider stops • keep size small',
        Regime.crisis => 'Defensive cash tilt • freeze new entries',
      };
}

Regime parseRegime(String? s) {
  switch (s?.toUpperCase()) {
    case 'BULL':
      return Regime.bull;
    case 'CHOPPY':
      return Regime.choppy;
    case 'HIGH_VOL_TREND':
      return Regime.highVolTrend;
    case 'CRISIS':
      return Regime.crisis;
    default:
      return Regime.bull;
  }
}

/// Per-asset regime with HMM posteriors.
class AssetRegime {
  final String asset;
  final Regime regime;
  final Map<Regime, double> posteriors;
  final double volQuantile;

  const AssetRegime({
    required this.asset,
    required this.regime,
    required this.posteriors,
    required this.volQuantile,
  });

  factory AssetRegime.fromJson(Map<String, dynamic> json) {
    final posteriorsRaw = json['posteriors'] as Map<String, dynamic>? ?? {};
    final posteriors = posteriorsRaw.map(
      (k, v) => MapEntry(parseRegime(k), (v as num).toDouble()),
    );
    return AssetRegime(
      asset: json['asset'] as String? ?? '',
      regime: parseRegime(json['regime'] as String?),
      posteriors: posteriors,
      volQuantile: (json['volQuantile'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// One slice of the recommended allocation pie.
class AllocationSlice {
  final String strategy;
  final double weight;

  const AllocationSlice(this.strategy, this.weight);

  factory AllocationSlice.fromJson(Map<String, dynamic> json) {
    return AllocationSlice(
      json['strategy'] as String? ?? '',
      (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full regime report from the backend.
class RegimeReport {
  final Regime globalRegime;
  final List<AssetRegime> perAsset;
  final List<AllocationSlice> allocation;
  final double maxLossTolerancePct;
  final double currentDrawdownPct;

  const RegimeReport({
    required this.globalRegime,
    required this.perAsset,
    required this.allocation,
    required this.maxLossTolerancePct,
    required this.currentDrawdownPct,
  });

  factory RegimeReport.fromJson(Map<String, dynamic> json) {
    final perAssetRaw = json['perAsset'] as List<dynamic>? ?? [];
    final allocRaw = json['allocation'] as List<dynamic>? ?? [];
    return RegimeReport(
      globalRegime: parseRegime(json['globalRegime'] as String?),
      perAsset: perAssetRaw
          .map((e) => AssetRegime.fromJson(e as Map<String, dynamic>))
          .toList(),
      allocation: allocRaw
          .map((e) => AllocationSlice.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxLossTolerancePct:
          (json['maxLossTolerancePct'] as num?)?.toDouble() ?? 3.0,
      currentDrawdownPct:
          (json['currentDrawdownPct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

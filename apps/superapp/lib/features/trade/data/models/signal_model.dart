/// Model for a trading signal (IDX / US / Crypto).
class SignalModel {
  final String name;
  final String value;
  final double strength; // 0..1
  final String sentiment; // bullish | bearish | neutral
  final String? paper;
  final List<double> series30d;
  final double? sharpe;
  final double? hitRate;
  final String asset; // idx | us | crypto

  const SignalModel({
    required this.name,
    required this.value,
    required this.strength,
    required this.sentiment,
    this.paper,
    this.series30d = const [],
    this.sharpe,
    this.hitRate,
    required this.asset,
  });

  factory SignalModel.fromJson(Map<String, dynamic> json) {
    return SignalModel(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      strength: (json['strength'] as num?)?.toDouble() ?? 0.0,
      sentiment: json['sentiment'] as String? ?? 'neutral',
      paper: json['paper'] as String?,
      series30d: (json['series30d'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      sharpe: (json['sharpe'] as num?)?.toDouble(),
      hitRate: (json['hitRate'] as num?)?.toDouble(),
      asset: json['asset'] as String? ?? 'idx',
    );
  }

  String get emoji => switch (sentiment) {
        'bullish' => '🟢',
        'bearish' => '🔴',
        _ => '🟡',
      };
}

/// Asset class enum for signal tabs.
enum AssetClass { idx, us, crypto }

extension AssetClassX on AssetClass {
  String get id => switch (this) {
        AssetClass.idx => 'idx',
        AssetClass.us => 'us',
        AssetClass.crypto => 'crypto',
      };
  String get label => switch (this) {
        AssetClass.idx => 'IDX',
        AssetClass.us => 'US',
        AssetClass.crypto => 'Crypto',
      };
}

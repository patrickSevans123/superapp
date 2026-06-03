/// A single trading decision from the AI decision memory.
class DecisionModel {
  final String ticker;
  final String decisionId;
  final String action; // BUY | SELL | HOLD
  final double entryPrice;
  final double takeProfit;
  final double stopLoss;
  final String horizon;
  final double confidence;
  final String reasoning;
  final String createdAt;
  final String? updatedAt;
  final double? realizedReturn;
  final double? alphaVsBenchmark;
  final String? reflection;
  final String? exitedAt;
  final double? exitPrice;

  const DecisionModel({
    required this.ticker,
    required this.decisionId,
    required this.action,
    required this.entryPrice,
    required this.takeProfit,
    required this.stopLoss,
    required this.horizon,
    required this.confidence,
    required this.reasoning,
    required this.createdAt,
    this.updatedAt,
    this.realizedReturn,
    this.alphaVsBenchmark,
    this.reflection,
    this.exitedAt,
    this.exitPrice,
  });

  factory DecisionModel.fromJson(Map<String, dynamic> json) {
    return DecisionModel(
      ticker: json['ticker'] as String? ?? '',
      decisionId: json['decision_id'] as String? ?? '',
      action: json['action'] as String? ?? 'HOLD',
      entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0.0,
      takeProfit: (json['take_profit'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (json['stop_loss'] as num?)?.toDouble() ?? 0.0,
      horizon: json['horizon'] as String? ?? 'SWING',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String?,
      realizedReturn: (json['realized_return'] as num?)?.toDouble(),
      alphaVsBenchmark: (json['alpha_vs_benchmark'] as num?)?.toDouble(),
      reflection: json['reflection'] as String?,
      exitedAt: json['exited_at'] as String?,
      exitPrice: (json['exit_price'] as num?)?.toDouble(),
    );
  }

  bool get isClosed => realizedReturn != null;
  
  String get actionEmoji => switch (action.toUpperCase()) {
        'BUY' => '🟢',
        'SELL' => '🔴',
        _ => '🟡',
      };
}

/// Learning stats from the decisions endpoint.
class LearningStats {
  final int totalDecisions;
  final int totalWithOutcomes;
  final double winRate;
  final double avgReturn;
  final double avgAlpha;

  const LearningStats({
    required this.totalDecisions,
    required this.totalWithOutcomes,
    required this.winRate,
    required this.avgReturn,
    required this.avgAlpha,
  });

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      totalDecisions: (json['totalDecisions'] as num?)?.toInt() ?? 0,
      totalWithOutcomes: (json['totalWithOutcomes'] as num?)?.toInt() ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
      avgReturn: (json['avgReturn'] as num?)?.toDouble() ?? 0.0,
      avgAlpha: (json['avgAlpha'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

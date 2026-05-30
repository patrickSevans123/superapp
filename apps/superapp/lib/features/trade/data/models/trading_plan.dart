/// Ported from self-trade mobile's plan.dart.
class TradingPlan {
  final String id;
  final String ticker;
  final String action;
  final double entryPrice;
  final double? tp;
  final double? sl;
  final String createdDate;
  final String status;
  final double? exitPrice;
  final String? exitDate;
  final String? outcome;
  final String? closeReason;
  final double? currentPrice;
  final double? pctChange;

  const TradingPlan({
    required this.id,
    required this.ticker,
    required this.action,
    required this.entryPrice,
    this.tp,
    this.sl,
    required this.createdDate,
    required this.status,
    this.exitPrice,
    this.exitDate,
    this.outcome,
    this.closeReason,
    this.currentPrice,
    this.pctChange,
  });

  factory TradingPlan.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic v) {
      if (v == null) return null;
      return v is num ? v.toDouble() : double.tryParse(v.toString());
    }

    return TradingPlan(
      id: json['id']?.toString() ?? '',
      ticker: json['ticker']?.toString() ?? '',
      action: json['action']?.toString() ?? 'BUY',
      entryPrice: parseNum(json['entry_price']) ?? 0,
      tp: parseNum(json['tp']),
      sl: parseNum(json['sl']),
      createdDate: json['created_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      exitPrice: parseNum(json['exit_price']),
      exitDate: json['exit_date']?.toString(),
      outcome: json['outcome']?.toString(),
      closeReason: json['close_reason']?.toString(),
      currentPrice: parseNum(json['current_price']),
      pctChange: parseNum(json['pct_change']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticker': ticker,
        'action': action,
        'entry_price': entryPrice,
        'tp': tp,
        'sl': sl,
        'created_date': createdDate,
        'status': status,
        'exit_price': exitPrice,
        'exit_date': exitDate,
        'outcome': outcome,
        'close_reason': closeReason,
        'current_price': currentPrice,
        'pct_change': pctChange,
      };

  bool get isActive => status == 'ACTIVE';
  bool get isClosed => status == 'CLOSED';
  bool get isWin => outcome == 'TP_HIT';
}

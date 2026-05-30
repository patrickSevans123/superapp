class MarketQuote {
  final String symbol;
  final String name;
  final double price;
  final double previousClose;
  final double change;
  final double changePct;
  final double high;
  final double low;
  final int volume;
  final String currency;
  final String timestamp;

  const MarketQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.previousClose,
    required this.change,
    required this.changePct,
    required this.high,
    required this.low,
    required this.volume,
    required this.currency,
    required this.timestamp,
  });

  factory MarketQuote.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0.0;
      return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      return v is int ? v : int.tryParse(v.toString()) ?? 0;
    }

    return MarketQuote(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: parseNum(json['price']),
      previousClose: parseNum(json['previous_close']),
      change: parseNum(json['change']),
      changePct: parseNum(json['change_pct']),
      high: parseNum(json['high']),
      low: parseNum(json['low']),
      volume: parseInt(json['volume']),
      currency: json['currency']?.toString() ?? 'USD',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'price': price,
        'previous_close': previousClose,
        'change': change,
        'change_pct': changePct,
        'high': high,
        'low': low,
        'volume': volume,
        'currency': currency,
        'timestamp': timestamp,
      };

  bool get isPositive => change >= 0;
}

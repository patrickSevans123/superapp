class PlansSummary {
  final int total;
  final int active;
  final int closed;
  final double winRatePct;
  final double avgReturnPct;

  const PlansSummary({
    required this.total,
    required this.active,
    required this.closed,
    required this.winRatePct,
    required this.avgReturnPct,
  });

  factory PlansSummary.fromJson(Map<String, dynamic> json) {
    return PlansSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      closed: (json['closed'] as num?)?.toInt() ?? 0,
      winRatePct: (json['win_rate_pct'] as num?)?.toDouble() ?? 0.0,
      avgReturnPct: (json['avg_return_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'active': active,
        'closed': closed,
        'win_rate_pct': winRatePct,
        'avg_return_pct': avgReturnPct,
      };
}

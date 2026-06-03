import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../data/models/trading_plan.dart';
import 'empty_chart_placeholder.dart';

/// Cumulative realised P&L over time, derived from closed [TradingPlan]s.
///
/// Closed plans are sorted by `exitDate` (falling back to `createdDate`),
/// and the running sum of per-trade `pctChange` is plotted.
///
/// The local `TradingPlan` model exposes `pctChange` (a percent) rather
/// than absolute IDR PnL, so the y-axis is formatted as percent.  When
/// the backend starts shipping an absolute `realized_return` field,
/// swap the body of [_cumulativeValue] to use it.
class PnlCurveChart extends StatelessWidget {
  final List<TradingPlan> closedPlans;

  const PnlCurveChart({super.key, required this.closedPlans});

  @override
  Widget build(BuildContext context) {
    if (closedPlans.length < 2) return const EmptyChartPlaceholder();
    final sorted = [...closedPlans]..sort(_byExit);
    final points = _cumulativePoints(sorted);
    if (points.length < 2) return const EmptyChartPlaceholder();

    final first = points.first;
    final last = points.last;
    final isPositive = last.value >= 0;
    final lineColor =
        isPositive ? AppColors.success : AppColors.error;
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.30),
        lineColor.withValues(alpha: 0.02),
      ],
    );

    final minV = points.map((p) => p.value).reduce(_min);
    final maxV = points.map((p) => p.value).reduce(_max);
    final yPad = (maxV - minV).abs() * 0.10 + 1.0;
    final minYBound = (minV < 0 ? minV : 0.0) - yPad;
    final maxYBound = (maxV > 0 ? maxV : 0.0) + yPad;

    // X-axis date format depends on time span.
    final spanDays = last.date.difference(first.date).inDays;
    final axisDateFmt =
        spanDays < 30 ? DateFormat('MMM dd') : DateFormat('MMM yy');
    final tooltipDateFmt = DateFormat('dd MMM yyyy');

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Realized P&L Curve',
            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'First trade: ${tooltipDateFmt.format(first.date)}'
            '  |  Last trade: ${tooltipDateFmt.format(last.date)}'
            '  |  Total: ${_fmtPct(last.value)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: minYBound,
                maxY: maxYBound,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxYBound - minYBound) / 4)
                      .clamp(1, double.infinity),
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: ((points.length - 1) / 3)
                          .clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        // Only show first / middle / last to avoid clutter.
                        if (idx != 0 &&
                            idx != points.length - 1 &&
                            idx != (points.length - 1) ~/ 2) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            axisDateFmt.format(points[idx].date),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.hint,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _fmtPct(value),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.hint,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.elevated,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${tooltipDateFmt.format(points[s.x.round()].date)}\n'
                            '${_fmtPct(s.y)}',
                            AppTextStyles.caption.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].value),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.28,
                    preventCurveOverShooting: true,
                    color: lineColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: points.length <= 30,
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: lineColor,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: fillGradient,
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: AppColors.border,
                      strokeWidth: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _CumPoint {
  final DateTime date;
  final double value;
  const _CumPoint(this.date, this.value);
}

List<_CumPoint> _cumulativePoints(List<TradingPlan> sorted) {
  final result = <_CumPoint>[];
  double running = 0;
  for (final p in sorted) {
    final pct = p.pctChange;
    if (pct == null) continue;
    running += pct;
    final dt = _parseDate(p.exitDate) ?? _parseDate(p.createdDate);
    if (dt == null) continue;
    result.add(_CumPoint(dt, running));
  }
  return result;
}

int _byExit(TradingPlan a, TradingPlan b) {
  final ad = _parseDate(a.exitDate) ?? _parseDate(a.createdDate);
  final bd = _parseDate(b.exitDate) ?? _parseDate(b.createdDate);
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return ad.compareTo(bd);
}

DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

String _fmtPct(double v) {
  final sign = v >= 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(2)}%';
}

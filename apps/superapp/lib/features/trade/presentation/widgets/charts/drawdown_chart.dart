import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../data/models/trading_plan.dart';
import 'empty_chart_placeholder.dart';

/// Running max drawdown (in percent points) from peak cumulative PnL.
///
/// The peak is the running maximum of cumulative `pctChange`. Drawdown
/// at any point = `current_cumulative - peak`, which is always ≤ 0.
/// Values are shown as negative on the chart (standard convention);
/// the subtitle displays the magnitude as a positive percentage.
class DrawdownChart extends StatelessWidget {
  final List<TradingPlan> closedPlans;

  const DrawdownChart({super.key, required this.closedPlans});

  @override
  Widget build(BuildContext context) {
    if (closedPlans.length < 2) return const EmptyChartPlaceholder();
    final sorted = [...closedPlans]..sort(_byExit);
    final ddPoints = _drawdownPoints(sorted);
    if (ddPoints.length < 2) return const EmptyChartPlaceholder();

    // ddPoints store negative % values. Most-negative = worst drawdown.
    final worst = ddPoints.map((p) => p.value).reduce(_min);
    final maxDD = worst.abs();
    // Clamp visual floor to -30% but allow it to grow if data exceeds it.
    final yFloor = worst < -30 ? worst : -30.0;
    final yPad = (yFloor.abs() * 0.10).clamp(0.5, 5.0);

    const lineColor = AppColors.error;
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.25),
        lineColor.withValues(alpha: 0.02),
      ],
    );

    final first = ddPoints.first;
    final last = ddPoints.last;
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
            'Drawdown',
            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Max drawdown: ${maxDD.toStringAsFixed(2)}%',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (ddPoints.length - 1).toDouble(),
                minY: yFloor - yPad,
                maxY: yPad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
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
                      interval: ((ddPoints.length - 1) / 3)
                          .clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx < 0 || idx >= ddPoints.length) {
                          return const SizedBox.shrink();
                        }
                        if (idx != 0 &&
                            idx != ddPoints.length - 1 &&
                            idx != (ddPoints.length - 1) ~/ 2) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            axisDateFmt.format(ddPoints[idx].date),
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
                      reservedSize: 40,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${value.toStringAsFixed(0)}%',
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
                            '${tooltipDateFmt.format(ddPoints[s.x.round()].date)}\n'
                            '${s.y.toStringAsFixed(2)}%',
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
                      for (var i = 0; i < ddPoints.length; i++)
                        FlSpot(i.toDouble(), ddPoints[i].value),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    preventCurveOverShooting: true,
                    color: lineColor,
                    barWidth: 2.0,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
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

class _DdPoint {
  final DateTime date;
  final double value; // negative %
  const _DdPoint(this.date, this.value);
}

List<_DdPoint> _drawdownPoints(List<TradingPlan> sorted) {
  final result = <_DdPoint>[];
  double running = 0;
  double peak = double.negativeInfinity;
  for (final p in sorted) {
    final pct = p.pctChange;
    if (pct == null) continue;
    running += pct;
    if (running > peak) peak = running;
    final ddPct = peak.isFinite ? (running - peak) : 0.0; // always ≤ 0
    final dt = _parseDate(p.exitDate) ?? _parseDate(p.createdDate);
    if (dt == null) continue;
    result.add(_DdPoint(dt, ddPct));
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

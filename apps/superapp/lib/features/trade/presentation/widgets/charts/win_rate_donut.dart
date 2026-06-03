import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../data/models/trading_plan.dart';
import 'empty_chart_placeholder.dart';

/// Donut chart showing the split between wins, losses, and breakeven
/// closed trades. The centre displays the overall win rate as an integer %.
class WinRateDonut extends StatelessWidget {
  final List<TradingPlan> closedPlans;

  const WinRateDonut({super.key, required this.closedPlans});

  static const _winColor = AppColors.success;
  static const _lossColor = AppColors.error;
  static const _beColor = AppColors.stone;

  @override
  Widget build(BuildContext context) {
    if (closedPlans.length < 2) {
      return const EmptyChartPlaceholder();
    }

    int wins = 0;
    int losses = 0;
    int breakeven = 0;
    for (final p in closedPlans) {
      if (!p.isClosed) continue;
      final r = _realizedReturn(p);
      if (r > 0.001) {
        wins++;
      } else if (r < -0.001) {
        losses++;
      } else {
        breakeven++;
      }
    }

    final total = wins + losses + breakeven;
    if (total == 0) return const EmptyChartPlaceholder();
    final winRatePct = (wins / total) * 100.0;

    final sections = <PieChartSectionData>[];
    if (wins > 0) {
      sections.add(PieChartSectionData(
        value: wins.toDouble(),
        color: _winColor,
        title: '$wins',
        radius: 28,
        titleStyle: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ));
    }
    if (losses > 0) {
      sections.add(PieChartSectionData(
        value: losses.toDouble(),
        color: _lossColor,
        title: '$losses',
        radius: 28,
        titleStyle: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ));
    }
    if (breakeven > 0) {
      sections.add(PieChartSectionData(
        value: breakeven.toDouble(),
        color: _beColor,
        title: '$breakeven',
        radius: 28,
        titleStyle: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ));
    }

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Win Rate',
            style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$wins wins / $losses losses / $breakeven BE',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 60,
                      sectionsSpace: 2,
                      startDegreeOffset: -90,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${winRatePct.toStringAsFixed(0)}%',
                        style: AppTextStyles.display.copyWith(fontSize: 28),
                      ),
                      Text(
                        'win',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _realizedReturn(TradingPlan p) {
  // Prefer the server-supplied pct_change if present.
  if (p.pctChange != null) return p.pctChange!;
  // Otherwise compute from entry/exit prices.
  if (p.exitPrice == null || p.entryPrice <= 0) return 0.0;
  return ((p.exitPrice! - p.entryPrice) / p.entryPrice) * 100.0;
}

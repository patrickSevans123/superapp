import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/models.dart';

/// A card that displays a single [TradingPlan].
///
/// Shows ticker, action, entry price, TP/SL, current price, and % change.
/// Wrapped in a [GlassCard] to match the superapp's glass-morphism theme.
class PlanCard extends StatelessWidget {
  final TradingPlan plan;

  const PlanCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final change = plan.entryPrice > 0
        ? ((plan.currentPrice ?? plan.entryPrice) - plan.entryPrice) /
                plan.entryPrice *
                100
        : 0.0;

    final isPositive = change >= 0;
    final date = _parseDate(plan.createdDate);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.ticker,
                      style: AppTextStyles.title.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.action} • Entry: ${_fmt(plan.entryPrice)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                if (plan.tp != null)
                  Text(
                    'TP: ${_fmt(plan.tp!)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (plan.sl != null)
                  Text(
                    'SL: ${_fmt(plan.sl!)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (date != null)
                  Text(
                    date,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
          if (plan.isActive)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppColors.success : AppColors.error,
                  ),
                ),
                if (plan.currentPrice != null)
                  Text(
                    _fmt(plan.currentPrice!),
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
              ],
            ),
          if (plan.isClosed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.outcome ?? 'CLOSED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: plan.isWin ? AppColors.success : AppColors.error,
                  ),
                ),
                if (plan.closeReason != null)
                  Text(
                    plan.closeReason!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final color = plan.isActive ? AppColors.accent : AppColors.stone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plan.status,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }

  String? _parseDate(String d) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String _fmt(double v) => NumberFormat('#,##0').format(v);
}

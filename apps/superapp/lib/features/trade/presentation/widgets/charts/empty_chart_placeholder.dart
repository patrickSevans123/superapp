import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

/// Reusable placeholder shown when there is not enough closed-trade data
/// to render the performance analytics charts.
///
/// Uses `ShimmerPlaceholder` from `shared_ui` as decorative accent bars
/// above and below the icon, matching the superapp's loading aesthetic.
class EmptyChartPlaceholder extends StatelessWidget {
  final String? message;
  final double height;

  const EmptyChartPlaceholder({
    super.key,
    this.message,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ShimmerPlaceholder(
                width: 120,
                height: 4,
                borderRadius: 2,
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.show_chart,
                size: 48,
                color: AppColors.hint,
              ),
              const SizedBox(height: 12),
              Text(
                message ??
                    'Charts appear after your first 2 closed trades.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 20),
              const ShimmerPlaceholder(
                width: 180,
                height: 4,
                borderRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

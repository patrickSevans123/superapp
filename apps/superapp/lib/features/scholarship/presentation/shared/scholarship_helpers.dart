// â”€â”€â”€ Shared Scholarship Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Extracted from browse_screen.dart, detail_screen.dart, saved_screen.dart
// to eliminate duplication.

import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COUNTRY â†’ FLAG
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

const _countryFlags = <String, String>{
  'Jerman': 'ðŸ‡©ðŸ‡ª',
  'Jepang': 'ðŸ‡¯ðŸ‡µ',
  'Uni Emirat Arab': 'ðŸ‡¦ðŸ‡ª',
  'Hongaria': 'ðŸ‡­ðŸ‡º',
  'Polandia': 'ðŸ‡µðŸ‡±',
};

String countryFlag(String country) => _countryFlags[country] ?? 'ðŸŒ';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DATE HELPERS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// Returns human-readable deadline info: days left, urgency level, etc.
class DeadlineInfo {
  final DateTime deadline;
  final int daysLeft;
  final bool isPast;
  final bool isUrgent; // â‰¤ 30 days
  final bool isToday;

  DeadlineInfo._({
    required this.deadline,
    required this.daysLeft,
    required this.isPast,
    required this.isUrgent,
    required this.isToday,
  });

  factory DeadlineInfo.fromDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now).inDays;
    return DeadlineInfo._(
      deadline: deadline,
      daysLeft: diff,
      isPast: diff < 0,
      isUrgent: diff >= 0 && diff <= 30,
      isToday: diff == 0,
    );
  }

  String get label {
    if (isPast) return 'Deadline Passed';
    if (isToday) return 'Due Today!';
    if (isUrgent) return '$daysLeft days left';
    final m = _months[deadline.month - 1];
    return 'Due $m ${deadline.day}';
  }

  IconData get icon {
    if (isPast) return Icons.block;
    if (isUrgent) return Icons.alarm;
    return Icons.event;
  }

  Color get color {
    if (isPast) return AppColors.error;
    if (isUrgent) return AppColors.warning;
    return AppColors.accent;
  }
}

// Convenience extension on DateTime for deadline info.
extension DeadlineInfoX on DateTime {
  DeadlineInfo get deadlineInfo => DeadlineInfo.fromDeadline(this);
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// FUNDING BADGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

enum FundingBadgeStyle { compact, full, withIcon }

/// Returns the display color for a funding type.
Color fundingBadgeColor(String fundingType) {
  return fundingType == 'Fully Funded' ? AppColors.success : AppColors.warning;
}

/// Returns the display label for a funding type.
String fundingBadgeLabel(String fundingType) {
  return fundingType == 'Fully Funded' ? 'Full' : 'Partial';
}

/// A reusable funding-type badge widget.
class ScholarshipFundingBadge extends StatelessWidget {
  final String fundingType;
  final FundingBadgeStyle style;

  const ScholarshipFundingBadge({
    super.key,
    required this.fundingType,
    this.style = FundingBadgeStyle.compact,
  });

  @override
  Widget build(BuildContext context) {
    final color = fundingBadgeColor(fundingType);

    return Container(
      padding: style == FundingBadgeStyle.compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(style == FundingBadgeStyle.compact ? 4 : 6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: style == FundingBadgeStyle.withIcon
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  fundingType == 'Fully Funded'
                      ? Icons.workspace_premium
                      : Icons.monetization_on,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  fundingType,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            )
          : Text(
              fundingBadgeLabel(fundingType),
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: color,
              ),
            ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// LEVEL BADGE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// A reusable education-level badge.
class ScholarshipLevelBadge extends StatelessWidget {
  final String level;

  const ScholarshipLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        level,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DEADLINE URGENCY BADGE (for grid cards)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class DeadlineUrgencyBadge extends StatelessWidget {
  final DeadlineInfo info;

  const DeadlineUrgencyBadge({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    if (info.isPast) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 8, color: info.color),
          const SizedBox(width: 2),
          Text(
            info.isUrgent ? '${info.daysLeft}d' : '',
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// COVERAGE ITEM WIDGET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class CoverageItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool covered;

  const CoverageItemWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.covered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: covered
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: covered ? AppColors.success : AppColors.hint,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.hint,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: covered ? AppColors.success : AppColors.stone,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

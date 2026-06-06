// Shared Scholarship Helpers
// Extracted from browse_screen.dart, detail_screen.dart, saved_screen.dart
// to eliminate duplication.

import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COUNTRY → FLAG
//
// Each flag is built from two Regional Indicator Symbols (U+1F1E6..U+1F1FF).
// We use Dart's \u{...} escape syntax so the source is pure ASCII and can
// never be re-mojibake'd by a non-UTF-8 editor. Covers all 51 unique
// country names found in services/beasiswa_crawler/data/scholarships.json.
// ─────────────────────────────────────────────────────────────────────────────

const _countryFlags = <String, String>{
  // A
  'Afrika Selatan': '\u{1F1FF}\u{1F1E6}',
  'Amerika Serikat': '\u{1F1FA}\u{1F1F8}',
  'Arab Saudi': '\u{1F1F8}\u{1F1E6}',
  'Australia': '\u{1F1E6}\u{1F1FA}',
  'Austria': '\u{1F1E6}\u{1F1F9}',
  'Azerbaijan': '\u{1F1E6}\u{1F1FF}',
  // B
  'Belanda': '\u{1F1F3}\u{1F1F1}',
  'Belgia': '\u{1F1E7}\u{1F1EA}',
  'Brunei': '\u{1F1E7}\u{1F1F3}',
  'Brunei Darussalam': '\u{1F1E7}\u{1F1F3}',
  // C
  'China': '\u{1F1E8}\u{1F1F3}',
  // D
  'Denmark': '\u{1F1E9}\u{1F1F0}',
  // E
  'Estonia': '\u{1F1EA}\u{1F1EA}',
  // F
  'Finlandia': '\u{1F1EB}\u{1F1EE}',
  // H
  'Hong Kong': '\u{1F1ED}\u{1F1F0}',
  'Hongaria': '\u{1F1ED}\u{1F1FA}',
  // I
  'Indonesia': '\u{1F1EE}\u{1F1E9}',
  'Inggris': '\u{1F1EC}\u{1F1E7}',
  'Irlandia': '\u{1F1EE}\u{1F1EA}',
  'Italia': '\u{1F1EE}\u{1F1F9}',
  // J
  'Jepang': '\u{1F1EF}\u{1F1F5}',
  'Jerman': '\u{1F1E9}\u{1F1EA}',
  // K
  'Kanada': '\u{1F1E8}\u{1F1E6}',
  'Kazakhstan': '\u{1F1F0}\u{1F1FF}',
  'Kolombia': '\u{1F1E8}\u{1F1F4}',
  'Korea Selatan': '\u{1F1F0}\u{1F1F7}',
  // L
  'Latvia': '\u{1F1F1}\u{1F1FB}',
  'Lithuania': '\u{1F1F1}\u{1F1F9}',
  // M
  'Malaysia': '\u{1F1F2}\u{1F1FE}',
  'Meksiko': '\u{1F1F2}\u{1F1FD}',
  'Mesir': '\u{1F1EA}\u{1F1EC}',
  'Multi Negara': '\u{1F30D}',
  // N
  'Norwegia': '\u{1F1F3}\u{1F1F4}',
  // P
  'Pakistan': '\u{1F1F5}\u{1F1F0}',
  'Polandia': '\u{1F1F5}\u{1F1F1}',
  'Portugal': '\u{1F1F5}\u{1F1F9}',
  'Prancis': '\u{1F1EB}\u{1F1F7}',
  'Perancis': '\u{1F1EB}\u{1F1F7}', // alias used by LPDP feature
  // Q
  'Qatar': '\u{1F1F6}\u{1F1E6}',
  // R
  'Republik Ceko': '\u{1F1E8}\u{1F1FF}',
  'Romania': '\u{1F1F7}\u{1F1F4}',
  'Russia': '\u{1F1F7}\u{1F1FA}',
  // S
  'Selandia Baru': '\u{1F1F3}\u{1F1FF}',
  'Singapura': '\u{1F1F8}\u{1F1EC}',
  'Siprus': '\u{1F1E8}\u{1F1FE}',
  'Slovakia': '\u{1F1F8}\u{1F1F0}',
  'Slowakia': '\u{1F1F8}\u{1F1F0}', // alternate spelling
  'Spanyol': '\u{1F1EA}\u{1F1F8}',
  'Swedia': '\u{1F1F8}\u{1F1EA}',
  'Swiss': '\u{1F1E8}\u{1F1ED}',
  // T
  'Taiwan': '\u{1F1F9}\u{1F1FC}',
  'Thailand': '\u{1F1F9}\u{1F1ED}',
  'Tiongkok': '\u{1F1E8}\u{1F1F3}', // alias used by LPDP feature
  'Turki': '\u{1F1F9}\u{1F1F7}',
  // U
  'Uni Emirat Arab': '\u{1F1E6}\u{1F1EA}',
  'Uni Eropa': '\u{1F1EA}\u{1F1FA}',
  // V
  'Vietnam': '\u{1F1FB}\u{1F1F3}',
};

/// Returns the emoji flag for [country], or a globe fallback for unknowns.
String countryFlag(String country) => _countryFlags[country] ?? '\u{1F30D}';

// ─────────────────────────────────────────────────────────────────────────────
// DATE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

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
  final bool isUrgent; // <= 30 days
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

// ─────────────────────────────────────────────────────────────────────────────
// FUNDING BADGE
// ─────────────────────────────────────────────────────────────────────────────

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
        borderRadius:
            BorderRadius.circular(style == FundingBadgeStyle.compact ? 4 : 6),
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

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL BADGE
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// DEADLINE URGENCY BADGE (for grid cards)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// COVERAGE ITEM WIDGET
// ─────────────────────────────────────────────────────────────────────────────

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

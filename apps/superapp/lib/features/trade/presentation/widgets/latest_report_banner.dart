// ─── Latest Daily Report Banner ─────────────────────────────────────────────
//
// A compact, dismissable banner shown at the top of the trade dashboard
// when all of the following are true:
//
// 1. The user has `new_report = true` in their notification preferences
//    (`settingsStateProvider.preferences.newReport`).
// 2. A daily report exists whose calendar day matches *today*
//    (device-local timezone — the report is generated in WIB but the
//    user might be elsewhere).
// 3. The user has not yet dismissed this banner (per-screen state).
//
// Tapping the body navigates to the daily reports list, where the
// matching report is the most recent entry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/reports_providers.dart';

class LatestReportBanner extends ConsumerStatefulWidget {
  const LatestReportBanner({super.key});

  @override
  ConsumerState<LatestReportBanner> createState() =>
      _LatestReportBannerState();
}

class _LatestReportBannerState extends ConsumerState<LatestReportBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    // Watch the user's `newReport` preference. Default to true so that
    // a fresh install (or one that hasn't loaded settings yet) still
    // shows the banner.
    final settings = ref.watch(settingsStateProvider);
    final prefs = settings.preferences;
    final newReportOn = prefs?.newReport ?? true;

    final latest = ref.watch(latestDailyReportProvider);
    return latest.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (report) {
        if (!newReportOn || report == null) {
          return const SizedBox.shrink();
        }
        final now = DateTime.now();
        if (!report.sameDayAs(now)) {
          return const SizedBox.shrink();
        }

        final time = DateFormat('HH:mm').format(report.date);
        final preview = _preview(report.title);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.tradeReports),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Today's report is out",
                          style: AppTextStyles.title.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$preview • $time',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.stone,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.tradeReports),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Open'),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.stone,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _preview(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Daily market summary';
    if (s.length <= 64) return s;
    return '${s.substring(0, 64).trim()}…';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/models.dart';
import '../providers/trade_providers.dart';

/// In-line banner that appears at the top of news surfaces when at least
/// one source is older than the freshness threshold.
///
/// Listens to [newsStatusProvider] (autoDispose, 60s polling on the server
/// side) and renders a dismissable card. The banner is purely visual — the
/// underlying data still loads — and it can be permanently hidden via the
/// "Don't show again" action.
class NewsFreshnessBanner extends ConsumerStatefulWidget {
  const NewsFreshnessBanner({super.key});

  @override
  ConsumerState<NewsFreshnessBanner> createState() =>
      _NewsFreshnessBannerState();
}

class _NewsFreshnessBannerState extends ConsumerState<NewsFreshnessBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final status = ref.watch(newsStatusProvider);
    return status.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if (s.allOk) return const SizedBox.shrink();
        return _StaleBanner(
          status: s,
          onDismiss: () => setState(() => _dismissed = true),
        );
      },
    );
  }
}

class _StaleBanner extends StatelessWidget {
  final NewsStatus status;
  final VoidCallback onDismiss;
  const _StaleBanner({required this.status, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final worst = status.sources.firstWhere(
      (s) => s.stale,
      orElse: () => status.sources.isNotEmpty
          ? status.sources.first
          : const SourceHealth(source: '?'),
    );
    final label = worst.ageLabel ?? '${worst.ageSeconds ?? 0}s';
    final threshold = worst.staleThresholdLabel ?? '12h';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_humaniseSource(worst.source)}: data stale',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated $label ago (threshold $threshold). ${status.stale} of ${status.total} source(s) need attention.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  String _humaniseSource(String s) {
    switch (s) {
      case 'bloomberg_english':
        return 'Bloomberg English';
      case 'bloomberg_technoz':
        return 'Bloomberg Technoz';
      case 'reuters':
        return 'Reuters';
      default:
        return s;
    }
  }
}

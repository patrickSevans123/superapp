// ─── Daily Reports Screen ────────────────────────────────────────────────────
//
// Lists end-of-day (and intra-day) trading reports.  Tapping a row swaps
// the body to a markdown detail view backed by the same in-memory record
// (no extra round-trip).  Reports are sorted newest-first by the backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/daily_report.dart';
import '../providers/reports_providers.dart';
import '../widgets/markdown_body.dart';

class DailyReportsScreen extends ConsumerStatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  ConsumerState<DailyReportsScreen> createState() =>
      _DailyReportsScreenState();
}

class _DailyReportsScreenState extends ConsumerState<DailyReportsScreen> {
  /// The report currently displayed in the inline detail view.
  /// When null, the list is shown.
  DailyReport? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return GlassScaffold(
      appBar: GlassAppBar(
        title: selected == null
            ? 'Daily Reports'
            : _formatLongDate(selected.date),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_selected != null) {
              setState(() => _selected = null);
            } else {
              context.go(AppRoutes.trade);
            }
          },
        ),
      ),
      body: GradientBackground(
        child: selected != null
            ? _ReportDetail(report: selected)
            : _ReportList(onTap: (r) => setState(() => _selected = r)),
      ),
    );
  }

  static String _formatLongDate(DateTime d) {
    return DateFormat('EEE, dd MMM yyyy').format(d);
  }
}

// ─── List view ─────────────────────────────────────────────────────────────

class _ReportList extends ConsumerWidget {
  final void Function(DailyReport) onTap;
  const _ReportList({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyReportsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyReportsProvider);
        // wait for the new future so the spinner stays visible briefly
        await ref.read(dailyReportsProvider.future);
      },
      child: async.when(
        loading: () => const _ReportListSkeleton(),
        error: (e, _) => _ReportError(
          message: e.toString(),
          onRetry: () => ref.invalidate(dailyReportsProvider),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const _ReportEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reports.length,
            itemBuilder: (_, i) => _ReportTile(
              report: reports[i],
              onTap: () => onTap(reports[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final DailyReport report;
  final VoidCallback onTap;
  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = _previewOf(report.title);
    final date = DateFormat('dd MMM yyyy').format(report.date);

    return MouseRegion(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.isEmpty ? '(untitled report)' : preview,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 12,
                        color: AppColors.hint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.hint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the first 100 characters of [raw] on a word boundary.
  String _previewOf(String raw) {
    final s = raw.trim();
    if (s.length <= 100) return s;
    final cut = s.substring(0, 100);
    final sp = cut.lastIndexOf(' ');
    return '${(sp > 60 ? cut.substring(0, sp) : cut).trim()}…';
  }
}

class _ReportListSkeleton extends StatelessWidget {
  const _ReportListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: ShimmerPlaceholder(height: 76, borderRadius: 12),
      ),
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  const _ReportEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView so RefreshIndicator still works
      children: [
        const SizedBox(height: 96),
        const Icon(
          Icons.description_outlined,
          size: 56,
          color: AppColors.hint,
        ),
        const SizedBox(height: 16),
        Text(
          'No daily reports yet',
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'They generate at 12:00 and 19:30 WIB. Pull to refresh, '
            'or check back later.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _ReportError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ReportError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 96),
        const Center(
          child: Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Could not load reports',
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GlassButton(
            label: 'Retry',
            icon: Icons.refresh,
            small: true,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

// ─── Detail view (inline) ──────────────────────────────────────────────────

class _ReportDetail extends StatelessWidget {
  final DailyReport report;
  const _ReportDetail({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEE, dd MMM yyyy • HH:mm').format(report.date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Report',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.title.isEmpty ? '(untitled report)' : report.title,
                style: AppTextStyles.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: AppColors.hint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.hint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: MarkdownBody(data: report.markdownBody),
        ),
      ],
    );
  }
}

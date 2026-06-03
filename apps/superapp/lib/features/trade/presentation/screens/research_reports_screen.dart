// ─── Research Reports List Screen ───────────────────────────────────────────
//
// Filterable list of broker research reports.  Source filter chips at the
// top drive a `family<ResearchReportSource?>` Riverpod provider so the
// request is keyed on the selected source and autoDispose-d when the
// user navigates away.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/research_report.dart';
import '../../data/models/research_report_source.dart';
import '../providers/reports_providers.dart';
import '../widgets/source_pill.dart';

class ResearchReportsListScreen extends ConsumerStatefulWidget {
  const ResearchReportsListScreen({super.key});

  @override
  ConsumerState<ResearchReportsListScreen> createState() =>
      _ResearchReportsListScreenState();
}

class _ResearchReportsListScreenState
    extends ConsumerState<ResearchReportsListScreen> {
  /// `null` = "All". Otherwise the source to filter by.
  ResearchReportSource? _selectedSource;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Research Reports',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.trade),
        ),
      ),
      body: GradientBackground(
        child: Column(
          children: [
            _SourceFilterBar(
              selected: _selectedSource,
              onSelect: (s) => setState(() => _selectedSource = s),
            ),
            Expanded(
              child: _ResearchList(
                source: _selectedSource,
                onSelectSource: (s) => setState(() => _selectedSource = s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Source filter chips ───────────────────────────────────────────────────

class _SourceFilterBar extends StatelessWidget {
  final ResearchReportSource? selected;
  final ValueChanged<ResearchReportSource?> onSelect;
  const _SourceFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sources = <(ResearchReportSource?, String)>[
      (null, 'All'),
      (ResearchReportSource.samuel, 'Samuel'),
      (ResearchReportSource.mandiri, 'Mandiri'),
      (ResearchReportSource.kiwoom, 'Kiwoom'),
      (ResearchReportSource.rk, 'RK'),
      (ResearchReportSource.revalue, 'Revalue'),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final (s, label) = sources[i];
          final isSelected = s == selected;
          return Center(
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelect(s),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accent : AppColors.stone,
              ),
              backgroundColor: AppColors.elevated,
              selectedColor: AppColors.accent.withValues(alpha: 0.18),
              side: BorderSide(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: sources.length,
      ),
    );
  }
}

// ─── List ──────────────────────────────────────────────────────────────────

class _ResearchList extends ConsumerWidget {
  final ResearchReportSource? source;
  final ValueChanged<ResearchReportSource?> onSelectSource;
  const _ResearchList({required this.source, required this.onSelectSource});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(researchReportsProvider(source));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(researchReportsProvider(source));
        await ref.read(researchReportsProvider(source).future);
      },
      child: async.when(
        loading: () => const _ResearchListSkeleton(),
        error: (e, _) => _ResearchError(
          message: e.toString(),
          onRetry: () => ref.invalidate(researchReportsProvider(source)),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return _ResearchEmpty(
              source: source,
              onClear: () => onSelectSource(null),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reports.length,
            itemBuilder: (_, i) => _ResearchTile(
              report: reports[i],
              onTap: () => context.push(
                AppRoutes.tradeResearchDetailFor(reports[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  final ResearchReport report;
  final VoidCallback onTap;
  const _ResearchTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(report.date);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SourcePill(source: report.source),
              const Spacer(),
              Text(
                dateStr,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.hint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.title.isEmpty ? '(untitled)' : report.title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (report.author.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              report.author,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
          if (report.tickers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in report.tickers.take(6))
                  SleekChip(t, small: true, accent: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResearchListSkeleton extends StatelessWidget {
  const _ResearchListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: ShimmerPlaceholder(height: 96, borderRadius: 12),
      ),
    );
  }
}

class _ResearchEmpty extends StatelessWidget {
  final ResearchReportSource? source;
  final VoidCallback onClear;
  const _ResearchEmpty({required this.source, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final sourceLabel = source?.label ?? 'any source';
    return ListView(
      children: [
        const SizedBox(height: 96),
        const Icon(
          Icons.assignment_outlined,
          size: 56,
          color: AppColors.hint,
        ),
        const SizedBox(height: 16),
        Text(
          'No research reports',
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            source == null
                ? 'No reports have been ingested yet. Pull to refresh, or check back later.'
                : 'No reports from $sourceLabel. Try a different source.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
        if (source != null) ...[
          const SizedBox(height: 20),
          Center(
            child: GlassButton(
              label: 'Show all sources',
              icon: Icons.clear_all,
              small: true,
              onPressed: onClear,
            ),
          ),
        ],
      ],
    );
  }
}

class _ResearchError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ResearchError({required this.message, required this.onRetry});

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
          'Could not load research reports',
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

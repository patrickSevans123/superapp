// ─── Research Report Detail Screen ──────────────────────────────────────────
//
// Markdown-rendered detail view for a single research report, with an
// "Open original PDF" action that launches the URL via url_launcher.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/research_report.dart';
import '../providers/reports_providers.dart';
import '../widgets/markdown_body.dart';
import '../widgets/source_pill.dart';

class ResearchReportDetailScreen extends ConsumerWidget {
  final String reportId;

  const ResearchReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(researchReportProvider(reportId));
    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Research Report',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.tradeResearch),
        ),
      ),
      body: GradientBackground(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          error: (e, _) => _ErrorView(
            message: _ErrorView.friendlyError(e),
            onRetry: () => ref.invalidate(researchReportProvider(reportId)),
          ),
          data: (report) => _DetailContent(report: report),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final ResearchReport report;
  const _DetailContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEE, dd MMM yyyy • HH:mm').format(report.date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Header card ───────────────────────────────────────────────
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SourcePill(source: report.source, fontSize: 11),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.hint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.title.isEmpty ? '(untitled)' : report.title,
                style: AppTextStyles.headline.copyWith(
                  fontSize: 22,
                  height: 1.25,
                ),
              ),
              if (report.author.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.hint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      report.author,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.stone,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Tickers ───────────────────────────────────────────────────
        if (report.tickers.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TICKERS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.hint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in report.tickers)
                      SleekChip(t, small: true, accent: true),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ── PDF action ────────────────────────────────────────────────
        if (report.pdfUrl != null && report.pdfUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          SleekButton(
            label: 'Open original PDF',
            icon: Icons.picture_as_pdf_outlined,
            variant: SleekButtonVariant.secondary,
            onPressed: () => _openPdf(context, report.pdfUrl!),
          ),
        ],

        // ── Body ──────────────────────────────────────────────────────
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: MarkdownBody(data: report.markdownBody),
        ),
      ],
    );
  }

  Future<void> _openPdf(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PDF URL')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  /// Strip the verbose "ReportsApiException(404): ..." prefix from a
  /// thrown exception so the user sees a clean message, not a stack
  /// trace. Falls back to the raw toString if the message is already
  /// friendly (no parenthesis prefix).
  static String friendlyError(Object e) {
    final s = e.toString();
    final colon = s.indexOf(': ');
    if (colon > 0 && s.startsWith('ReportsApiException')) {
      return s.substring(colon + 2);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load report',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Scholarship Stats Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/app_routes.dart';
import '../providers/scholarship_providers.dart';
import '../shared/scholarship_helpers.dart';

class StatsDashboardScreen extends ConsumerStatefulWidget {
  const StatsDashboardScreen({super.key});

  @override
  ConsumerState<StatsDashboardScreen> createState() =>
      _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends ConsumerState<StatsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(scholarshipStatsProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: 'Scholarship Stats',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.scholarship),
        ),
      ),
      body: GradientBackground(
        child: statsAsync.when(
          loading: () => _buildShimmer(),
          error: (err, _) => _buildError(err),
          data: (stats) => _buildContent(stats),
        ),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load stats',
              style: AppTextStyles.title.copyWith(color: AppColors.stone),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(scholarshipStatsProvider),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Shimmer Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total card
            _shimmerBox(height: 100),
            const SizedBox(height: 12),
            // Deadline row
            Row(
              children: [
                Expanded(child: _shimmerBox(height: 80)),
                const SizedBox(width: 12),
                Expanded(child: _shimmerBox(height: 80)),
              ],
            ),
            const SizedBox(height: 16),
            // Countries header
            _shimmerBox(height: 20, width: 140),
            const SizedBox(height: 12),
            ...List.generate(5, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _shimmerBox(height: 44),
                )),
            const SizedBox(height: 16),
            // Funding header
            _shimmerBox(height: 20, width: 180),
            const SizedBox(height: 12),
            Row(
              children: [
                _shimmerBox(height: 36, width: 140),
                const SizedBox(width: 10),
                _shimmerBox(height: 36, width: 120),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({double height = 20, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // â”€â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContent(Map<String, dynamic> stats) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(scholarshipStatsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTotalCard(stats),
            const SizedBox(height: 12),
            _buildDeadlineRow(stats),
            const SizedBox(height: 20),
            _buildTopCountries(stats),
            const SizedBox(height: 20),
            _buildFundingBreakdown(stats),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Total Count Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTotalCard(Map<String, dynamic> stats) {
    final total = _intVal(stats['total']);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school,
              size: 28,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Scholarships',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.hint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(total),
                  style: AppTextStyles.display.copyWith(
                    fontSize: 32,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Deadline Cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDeadlineRow(Map<String, dynamic> stats) {
    final thisMonth = _intVal(stats['deadlines_this_month']);
    final next30 = _intVal(stats['deadlines_next_30_days']);
    return Row(
      children: [
        Expanded(
          child: _buildDeadlineCard(
            thisMonth,
            'Deadlines This Month',
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDeadlineCard(
            next30,
            'Deadlines Next 30 Days',
            AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineCard(int count, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                _formatNumber(count),
                style: AppTextStyles.headline.copyWith(
                  fontSize: 24,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.stone,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Top Countries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTopCountries(Map<String, dynamic> stats) {
    final byCountry = stats['by_country'];
    if (byCountry == null ||
        (byCountry is Map && byCountry.isEmpty)) {
      return const SizedBox.shrink();
    }

    final entries =
        (byCountry as Map<String, dynamic>).entries.toList()
          ..sort(
              (a, b) => (b.value as num).compareTo(a.value as num));
    final top = entries.take(10).toList();
    final maxCount =
        top.isNotEmpty ? (top.first.value as num).toDouble() : 1.0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Top Countries',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...top.map(
            (entry) => _buildCountryRow(
              entry.key,
              (entry.value as num).toInt(),
              maxCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryRow(
      String country, int count, double maxCount) {
    final ratio = maxCount > 0 ? count / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(countryFlag(country),
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              country,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          // Horizontal bar
          Expanded(
            flex: 2,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Funding Type Breakdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildFundingBreakdown(Map<String, dynamic> stats) {
    final byFunding = stats['by_funding_type'];
    if (byFunding == null ||
        (byFunding is Map && byFunding.isEmpty)) {
      return const SizedBox.shrink();
    }

    final entries =
        (byFunding as Map<String, dynamic>).entries.toList();
    final total =
        entries.fold<int>(0, (sum, e) => sum + (e.value as num).toInt());

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Funding Type',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...entries.map((entry) {
            final count = (entry.value as num).toInt();
            final pct =
                total > 0 ? '${(count / total * 100).toStringAsFixed(0)}%' : '0%';
            final isFull = entry.key == 'Fully Funded';
            final color = isFull ? AppColors.success : AppColors.warning;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      entry.key,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count ($pct)',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // â”€â”€â”€ Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuickActions() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: AppTextStyles.title.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'View Upcoming Deadlines',
            icon: Icons.event,
            onPressed: () => context.go(AppRoutes.scholarshipDeadlineDays(30)),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  int _intVal(dynamic v) => (v as num?)?.toInt() ?? 0;

  String _formatNumber(int n) {
    if (n >= 10000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

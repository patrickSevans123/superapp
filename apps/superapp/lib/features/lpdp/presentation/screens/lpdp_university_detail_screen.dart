// â”€â”€â”€ LPDP University Detail Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lpdp_models.dart';
import '../providers/lpdp_providers.dart';

// â”€â”€â”€ University Detail Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class LpdpUniversityDetailScreen extends ConsumerWidget {
  final String name;

  const LpdpUniversityDetailScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(lpdpUnivDetailProvider(name));

    return detailAsync.when(
      loading: () => GlassScaffold(
        appBar: GlassAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.lpdpUniversities),
          ),
          title: 'Loading...',
        ),
        body: GradientBackground(
          child: _buildSkeleton(),
        ),
      ),
      error: (err, _) => GlassScaffold(
        appBar: GlassAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.lpdpUniversities),
          ),
          title: 'Error',
        ),
        body: GradientBackground(
          child: _buildError(context, err, ref),
        ),
      ),
      data: (univ) => GlassScaffold(
        appBar: GlassAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.lpdpUniversities),
          ),
          title: univ.name,
        ),
        body: GradientBackground(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(lpdpUnivDetailProvider(name)),
            color: AppColors.accent,
            backgroundColor: AppColors.elevated,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(univ),
                  const SizedBox(height: 16),
                  if (univ.description != null)
                    _buildDescription(univ.description!),
                  if (univ.description != null)
                    const SizedBox(height: 16),
                  _buildProgramsByBidang(univ),
                  const SizedBox(height: 16),
                  if (univ.website != null)
                    _buildWebsiteButton(univ.website!),
                  const SizedBox(height: 16),
                  _buildProgramsList(univ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeader(LpdpUniversity univ) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                univ.name.isNotEmpty
                    ? univ.name[0].toUpperCase()
                    : 'U',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 22,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  univ.name,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.public,
                        size: 14, color: AppColors.stone),
                    const SizedBox(width: 4),
                    Text(
                      univ.country,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.stone,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.school,
                        size: 14, color: AppColors.stone),
                    const SizedBox(width: 4),
                    Text(
                      '${univ.programCount} program${univ.programCount == 1 ? '' : 's'}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.stone,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Description â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDescription(String description) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'About',
                style: AppTextStyles.title.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: AppColors.stone,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Programs Grouped by Bidang Strategis â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildProgramsByBidang(LpdpUniversity univ) {
    final byBidang = univ.programsByBidang;
    if (byBidang.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Bidang Strategis',
                style: AppTextStyles.title.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: byBidang.entries.map((entry) {
              final bidang = findBidang(entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bidang != null)
                      Icon(bidang.icon,
                          size: 12, color: AppColors.accent),
                    if (bidang != null)
                      const SizedBox(width: 4),
                    Text(
                      '${entry.key} (${entry.value.length})',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Full Programs List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildProgramsList(LpdpUniversity univ) {
    if (univ.programs.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No program data available',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.hint,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level filter tabs would go here, but for now we group by level
        if (univ.magisterPrograms.isNotEmpty) ...[
          _buildLevelSection('Magister (S2)', univ.magisterPrograms),
          const SizedBox(height: 16),
        ],
        if (univ.doktorPrograms.isNotEmpty)
          _buildLevelSection('Doktor (S3)', univ.doktorPrograms),
      ],
    );
  }

  Widget _buildLevelSection(String title, List<LpdpProgram> programs) {
    // Group by bidang within level
    final byBidang = <String, List<LpdpProgram>>{};
    for (final p in programs) {
      byBidang.putIfAbsent(p.bidangStrategis, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${programs.length} program${programs.length == 1 ? '' : 's'}',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.stone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Programs grouped by bidang
        ...byBidang.entries.map(
          (entry) => _buildBidangGroup(entry.key, entry.value),
        ),
      ],
    );
  }

  // â”€â”€â”€ Bidang Group Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBidangGroup(String bidangName, List<LpdpProgram> programs) {
    final bidang = findBidang(bidangName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bidang header
            Row(
              children: [
                if (bidang != null)
                  Icon(bidang.icon, size: 14, color: AppColors.accent),
                if (bidang != null) const SizedBox(width: 6),
                Text(
                  bidangName,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Programs in this bidang
            ...programs.map(
              (program) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        size: 6, color: AppColors.stone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        program.name,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          color: AppColors.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Website Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildWebsiteButton(String website) {
    return GlassButton(
      label: 'Visit Website',
      icon: Icons.open_in_new,
      onPressed: () async {
        final uri = Uri.tryParse(website);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri,
              mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  // â”€â”€â”€ Skeleton Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.elevated,
      highlightColor: AppColors.borderHover,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBox(height: 80),
            const SizedBox(height: 16),
            _skeletonBox(height: 100),
            const SizedBox(height: 16),
            _skeletonBox(height: 60),
            const SizedBox(height: 16),
            _skeletonBox(height: 200),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({double height = 20}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildError(
      BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load university details',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
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
              onPressed: () =>
                  ref.invalidate(lpdpUnivDetailProvider(name)),
            ),
          ],
        ),
      ),
    );
  }
}

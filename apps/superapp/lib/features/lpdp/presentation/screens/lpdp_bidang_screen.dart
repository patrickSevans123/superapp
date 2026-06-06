// â”€â”€â”€ LPDP Bidang Strategis Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lpdp_models.dart';
import '../providers/lpdp_providers.dart';

// â”€â”€â”€ Bidang Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class LpdpBidangScreen extends ConsumerWidget {
  final String bidang;

  const LpdpBidangScreen({super.key, required this.bidang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decodedBidang = Uri.decodeComponent(bidang);
    final bidangInfo = findBidang(decodedBidang);
    final programsAsync = ref.watch(lpdpBidangProgramsProvider(decodedBidang));

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.lpdp),
        ),
        title: decodedBidang,
      ),
      body: GradientBackground(
        child: programsAsync.when(
          loading: () => _buildSkeleton(),
          error: (err, _) => _buildError(context, err, ref, decodedBidang),
          data: (programs) => _buildContent(
            context, ref, decodedBidang, bidangInfo, programs,
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String decodedBidang,
    LpdpBidangInfo? bidangInfo,
    List<LpdpProgram> programs,
  ) {
    // Group programs by university
    final byUniversity = <String, List<LpdpProgram>>{};
    for (final p in programs) {
      byUniversity.putIfAbsent(p.universityName, () => []).add(p);
    }

    final totalPrograms = programs.length;
    final totalUniversities = byUniversity.length;

    // Count levels
    final magisterCount =
        programs.where((p) => p.level == 'Magister').length;
    final doktorCount =
        programs.where((p) => p.level == 'Doktor').length;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(lpdpBidangProgramsProvider(decodedBidang)),
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero section
            _buildHero(decodedBidang, bidangInfo, totalPrograms),
            const SizedBox(height: 16),

            // Stats row
            _buildStatsRow(
              totalPrograms, totalUniversities, magisterCount, doktorCount,
            ),
            const SizedBox(height: 20),

            // Programs by university
            Text(
              'Programs by University',
              style: AppTextStyles.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),

            ...byUniversity.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUniversitySection(
                    context, entry.key, entry.value, ref),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Hero â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHero(
    String name,
    LpdpBidangInfo? info,
    int totalPrograms,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Icon(
              info?.icon ?? Icons.explore_outlined,
              size: 24,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 20,
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    info.description,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.stone,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Stats Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatsRow(
    int totalPrograms,
    int totalUniversities,
    int magisterCount,
    int doktorCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            Icons.menu_book_rounded,
            '$totalPrograms',
            'Total Programs',
            AppColors.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStatCard(
            Icons.school,
            '$totalUniversities',
            'Universities',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStatCard(
            Icons.grade_outlined,
            '${magisterCount + doktorCount}',
            'S2 \u00B7 $magisterCount / S3 \u00B7 $doktorCount',
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(
      IconData icon, String value, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: AppColors.stone,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ University Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildUniversitySection(
    BuildContext context,
    String universityName,
    List<LpdpProgram> programs,
    WidgetRef ref,
  ) {
    final magister = programs.where((p) => p.level == 'Magister').toList();
    final doktor = programs.where((p) => p.level == 'Doktor').toList();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go(
        '/lpdp/university/${Uri.encodeComponent(universityName)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // University name + arrow
          Row(
            children: [
              Expanded(
                child: Text(
                  universityName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.hint),
            ],
          ),
          const SizedBox(height: 8),

          // Program count
          Text(
            '${programs.length} program${programs.length == 1 ? '' : 's'}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.stone,
            ),
          ),
          const SizedBox(height: 6),

          // Level badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (magister.isNotEmpty)
                _levelBadge('Magister', magister.length),
              if (doktor.isNotEmpty)
                _levelBadge('Doktor', doktor.length),
            ],
          ),
          const SizedBox(height: 8),

          // Program names
          ...programs.take(3).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 5, color: AppColors.stone),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.name,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10.5,
                        color: AppColors.stone,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (programs.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${programs.length - 3} more',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelBadge(String level, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$level \u00B7 $count',
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
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
            Row(
              children: [
                Expanded(child: _skeletonBox(height: 80)),
                const SizedBox(width: 8),
                Expanded(child: _skeletonBox(height: 80)),
                const SizedBox(width: 8),
                Expanded(child: _skeletonBox(height: 80)),
              ],
            ),
            const SizedBox(height: 20),
            _skeletonBox(height: 20, width: 180),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _skeletonBox(height: 120),
            )),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({double height = 20, double? width}) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildError(
    BuildContext context,
    Object error,
    WidgetRef ref,
    String decodedBidang,
  ) {
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
              'Failed to load programs',
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
                  ref.invalidate(lpdpBidangProgramsProvider(decodedBidang)),
            ),
          ],
        ),
      ),
    );
  }
}

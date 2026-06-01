// â”€â”€â”€ LPDP Dashboard Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lpdp_models.dart';
import '../providers/lpdp_providers.dart';

// â”€â”€â”€ Dashboard Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class LpdpDashboardScreen extends ConsumerStatefulWidget {
  const LpdpDashboardScreen({super.key});

  @override
  ConsumerState<LpdpDashboardScreen> createState() =>
      _LpdpDashboardScreenState();
}

class _LpdpDashboardScreenState extends ConsumerState<LpdpDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(lpdpStatsProvider);
    final univAsync = ref.watch(lpdpUniversitiesProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.scholarship),
        ),
        title: 'LPDP Unggulan',
      ),
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(lpdpStatsProvider);
            ref.invalidate(lpdpUniversitiesProvider);
            await Future.wait([
              ref.read(lpdpStatsProvider.future),
              ref.read(lpdpUniversitiesProvider.future),
            ]);
          },
          color: AppColors.accent,
          backgroundColor: AppColors.elevated,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(),
                const SizedBox(height: 20),

                // Stats cards
                statsAsync.when(
                  loading: () => _buildStatsShimmer(),
                  error: (err, _) => _buildStatsError(err),
                  data: (stats) => _buildStatsRow(stats),
                ),
                const SizedBox(height: 24),

                // Section header + Browse Universities button
                Row(
                  children: [
                    Text(
                      'Bidang Strategis',
                      style: AppTextStyles.title.copyWith(fontSize: 17),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.lpdpUniversities),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All Universities',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_forward_ios,
                                size: 8, color: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bidang Strategis grid
                _buildBidangGrid(univAsync),
                const SizedBox(height: 24),

                // Footer description
                _buildFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Hero Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeroSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LPDP Logo / branding
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child:               const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LPDP Unggulan',
                    style: AppTextStyles.headline.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Beasiswa Pendidikan Indonesia',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.stone,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'LPDP berkomitmen untuk mempersiapkan pemimpin dan '
            'profesional masa depan melalui beasiswa pendidikan '
            'di perguruan tinggi terbaik dunia. Program Beasiswa '
            'Unggulan LPDP mencakup 17 universitas mitra di '
            'berbagai negara dengan fokus pada 8 bidang strategis '
            'nasional.',
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              color: AppColors.stone,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: 'Browse Universities',
            icon: Icons.school,
            small: true,
            onPressed: () => context.go(AppRoutes.lpdpUniversities),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Stats Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatsRow(LpdpStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.school,
            '${stats.totalUniversities}',
            'Universities',
            AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.menu_book_rounded,
            '${stats.totalPrograms}',
            'Programs',
            AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.public,
            '${stats.totalCountries}',
            'Countries',
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headline.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: AppColors.stone,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Stats Shimmer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.elevated,
      highlightColor: AppColors.borderHover,
      child: Row(
        children: List.generate(
          3,
           (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(
                  right: i == 2 ? 0 : 10),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsError(Object error) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 18, color: AppColors.error.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load stats',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error.withValues(alpha: 0.7),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.invalidate(lpdpStatsProvider),
            child: const Icon(Icons.refresh,
                size: 18, color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Bidang Strategis Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBidangGrid(AsyncValue<List<LpdpUniversity>> univAsync) {
    // Build a map of bidang â†’ program count from universities data
    final bidangCounts = <String, int>{};
    univAsync.whenData((universities) {
      for (final u in universities) {
        for (final p in u.programs) {
          bidangCounts.update(
            p.bidangStrategis,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
      }
    });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: lpdpBidangList.length,
      itemBuilder: (context, index) {
        final bidang = lpdpBidangList[index];
        final count = bidangCounts[bidang.name] ?? 0;
        return _buildBidangCard(bidang, count);
      },
    );
  }

  Widget _buildBidangCard(LpdpBidangInfo bidang, int programCount) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go(AppRoutes.lpdpBidangFor(bidang.name)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              bidang.icon,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          // Name
          Text(
            bidang.name,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: AppColors.ink,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          // Program count
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 11, color: AppColors.hint),
              const SizedBox(width: 4),
              Text(
                '$programCount program${programCount == 1 ? '' : 's'}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.stone,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  size: 8, color: AppColors.hint),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildFooter() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Tentang LPDP',
                style: AppTextStyles.title.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Lembaga Pengelola Dana Pendidikan (LPDP) adalah '
            'lembaga di bawah Kementerian Keuangan RI yang '
            'mengelola dana abadi pendidikan. Program Beasiswa '
            'Unggulan LPDP bertujuan untuk menyiapkan sumber daya '
            'manusia unggul Indonesia melalui pendidikan di 17 '
            'universitas terbaik dunia yang relevan dengan bidang '
            'strategis nasional.',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.stone,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bidang strategis mencakup: Digitalisasi, Energi, '
            'Hilirisasi, Kesehatan, Ketahanan Pangan, Maritim, '
            'Material dan Manufaktur, serta Pertahanan.',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.hint,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

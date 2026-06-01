// â”€â”€â”€ LPDP University List Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/lpdp_models.dart';
import '../providers/lpdp_providers.dart';

// â”€â”€â”€ Country Flag Helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _countryFlags = <String, String>{
  'Australia': 'ðŸ‡¦ðŸ‡º',
  'Belanda': 'ðŸ‡³ðŸ‡±',
  'Inggris': 'ðŸ‡¬ðŸ‡§',
  'Jepang': 'ðŸ‡¯ðŸ‡µ',
  'Jerman': 'ðŸ‡©ðŸ‡ª',
  'Korea Selatan': 'ðŸ‡°ðŸ‡·',
  'Perancis': 'ðŸ‡«ðŸ‡·',
  'Singapura': 'ðŸ‡¸ðŸ‡¬',
  'Swedia': 'ðŸ‡¸ðŸ‡ª',
  'Swiss': 'ðŸ‡¨ðŸ‡­',
  'Tiongkok': 'ðŸ‡¨ðŸ‡³',
  'Amerika Serikat': 'ðŸ‡ºðŸ‡¸',
  'Kanada': 'ðŸ‡¨ðŸ‡¦',
};

String _countryFlag(String country) => _countryFlags[country] ?? 'ðŸŒ';

// â”€â”€â”€ University List Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class LpdpUniversityListScreen extends ConsumerStatefulWidget {
  const LpdpUniversityListScreen({super.key});

  @override
  ConsumerState<LpdpUniversityListScreen> createState() =>
      _LpdpUniversityListScreenState();
}

class _LpdpUniversityListScreenState
    extends ConsumerState<LpdpUniversityListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final univAsync = ref.watch(lpdpUniversitiesProvider);

    return GlassScaffold(
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.lpdp),
        ),
        title: 'LPDP Universities',
      ),
      body: GradientBackground(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassTextField(
                controller: _searchController,
                hintText: 'Search universities...',
                prefixIcon: Icons.search,
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),

            // Content
            Expanded(
              child: univAsync.when(
                loading: () => _buildSkeletonGrid(),
                error: (err, _) => _buildError(err),
                data: (universities) =>
                    _buildContent(universities),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContent(List<LpdpUniversity> universities) {
    final filtered = _searchQuery.isEmpty
        ? universities
        : universities
            .where((u) =>
                u.name.toLowerCase().contains(_searchQuery) ||
                u.country.toLowerCase().contains(_searchQuery))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(lpdpUniversitiesProvider),
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _buildUniversityCard(filtered[index]),
      ),
    );
  }

  // â”€â”€â”€ University Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildUniversityCard(LpdpUniversity univ) {
    final magisterCount = univ.magisterPrograms.length;
    final doktorCount = univ.doktorPrograms.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () =>
            context.go(AppRoutes.lpdpUniversityFor(univ.name)),
        child: Row(
          children: [
            // Flag + icon area
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Text(
                  _countryFlag(univ.country),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    univ.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Country
                  Row(
                    children: [
                      Text(
                        _countryFlag(univ.country),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        univ.country,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.stone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Program counts
                  Row(
                    children: [
                      if (magisterCount > 0) ...[
                        _buildLevelBadge('S2', magisterCount),
                        const SizedBox(width: 6),
                      ],
                      if (doktorCount > 0)
                        _buildLevelBadge('S3', doktorCount),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$level Â· $count',
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
    );
  }

  // â”€â”€â”€ Skeleton Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSkeletonGrid() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: AppColors.elevated,
          highlightColor: AppColors.borderHover,
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            height: 16,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.hint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No universities found'
                  : 'No universities match your search',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isEmpty
                  ? 'Check back later for updates'
                  : 'Try a different search term',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildError(Object error) {
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
              'Failed to load universities',
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
                  ref.invalidate(lpdpUniversitiesProvider),
            ),
          ],
        ),
      ),
    );
  }
}

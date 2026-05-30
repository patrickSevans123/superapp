// ─── Browse Scholarship Screen ────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/scholarship_model.dart';
import '../providers/scholarship_providers.dart';

// ─── Country → Flag Emoji Helper ─────────────────────────────────────────

String _countryFlag(String country) {
  const flags = <String, String>{
    'Jerman': '🇩🇪',
    'Jepang': '🇯🇵',
    'Korea Selatan': '🇰🇷',
    'Tiongkok': '🇨🇳',
    'Amerika Serikat': '🇺🇸',
    'Inggris': '🇬🇧',
    'Australia': '🇦🇺',
    'Singapura': '🇸🇬',
    'Belanda': '🇳🇱',
    'Swiss': '🇨🇭',
    'Indonesia': '🇮🇩',
    'Perancis': '🇫🇷',
    'Kanada': '🇨🇦',
    'Swedia': '🇸🇪',
    'Italia': '🇮🇹',
    'Finlandia': '🇫🇮',
  };
  return flags[country] ?? '🌍';
}

// ─── Browse Screen ───────────────────────────────────────────────────────

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scholarshipsAsync = ref.watch(scholarshipsProvider);
    final filters = ref.watch(browseFiltersProvider);

    return GradientBackground(
      child: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GlassTextField(
              controller: _searchController,
              hintText: 'Search scholarships...',
              prefixIcon: Icons.search,
              onChanged: (value) {
                ref.read(browseFiltersProvider.notifier).setSearch(value);
              },
            ),
          ),

          // ── Filter Chips ───────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Level chips
                ..._chipGroup(
                  context,
                  ref,
                  filters,
                  label: 'Level',
                  options: const ['All', 'S1', 'S2', 'S3'],
                  selected: filters.level,
                  onSelect: (v) =>
                      ref.read(browseFiltersProvider.notifier).setLevel(v),
                ),

                const SizedBox(width: 8),

                // Country chips
                ..._chipGroup(
                  context,
                  ref,
                  filters,
                  label: 'Country',
                  options: allCountryOptions,
                  selected: filters.country,
                  onSelect: (v) =>
                      ref.read(browseFiltersProvider.notifier).setCountry(v),
                ),

                const SizedBox(width: 8),

                // Funding chips
                ..._chipGroup(
                  context,
                  ref,
                  filters,
                  label: 'Funding',
                  options: const ['All', 'Fully Funded', 'Partial'],
                  selected: filters.funding,
                  onSelect: (v) =>
                      ref.read(browseFiltersProvider.notifier).setFunding(v),
                ),
              ],
            ),
          ),

          // ── Result Count ───────────────────────────────────────────────
          scholarshipsAsync.whenOrNull(
                data: (data) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${data.length} scholarship${data.length == 1 ? '' : 's'} found',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.stone,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ) ??
              const SizedBox.shrink(),

          // ── Main Content ───────────────────────────────────────────────
          Expanded(
            child: scholarshipsAsync.when(
              loading: () => _buildSkeletonGrid(),
              error: (err, _) => _buildError(context, err, ref),
              data: (scholarships) {
                if (scholarships.isEmpty) {
                  return _buildEmpty(context, ref);
                }
                return _buildGrid(context, scholarships, ref);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chip Group Builder ───────────────────────────────────────────────

  List<Widget> _chipGroup(
    BuildContext context,
    WidgetRef ref,
    BrowseFilters filters, {
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final chips = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      final isSelected = selected == option;
      chips.add(
        Padding(
          padding: EdgeInsets.only(
            left: i == 0 ? 0 : 6,
            right: i == options.length - 1 ? 0 : 0,
          ),
          child: ChoiceChip(
            label: Text(
              option == 'Fully Funded' ? 'Full' : option,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.ink : AppColors.stone,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelect(option),
            selectedColor: AppColors.accent.withOpacity(0.25),
            backgroundColor: AppColors.elevated,
            side: BorderSide(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.5)
                  : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }
    return chips;
  }

  // ─── Scholarship Card ────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, ScholarshipModel s, WidgetRef ref) {
    final deadlineStr = s.deadline != null
        ? 'Due ${_formatDate(s.deadline!)}'
        : null;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.go('/scholarship/${s.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            s.title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: AppColors.ink,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Provider
          Text(
            s.provider,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.stone,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),

          // Country
          Row(
            children: [
              Text(
                _countryFlag(s.country),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  s.country,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.stone,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Level badges + Funding badge
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Level badges
              ...s.level.map(
                (l) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    l,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 2),

              // Funding type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: s.fundingType == 'Fully Funded'
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: s.fundingType == 'Fully Funded'
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  s.fundingType == 'Fully Funded' ? 'Full' : 'Partial',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: s.fundingType == 'Fully Funded'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),

          // Deadline
          if (deadlineStr != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 10, color: AppColors.hint),
                const SizedBox(width: 3),
                Text(
                  deadlineStr,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.hint,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Grid ─────────────────────────────────────────────────────────────

  Widget _buildGrid(
      BuildContext context, List<ScholarshipModel> data, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(scholarshipsProvider);
        await ref.read(scholarshipsProvider.future);
      },
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.68,
        ),
        itemCount: data.length,
        itemBuilder: (context, index) => _buildCard(context, data[index], ref),
      ),
    );
  }

  // ─── Shimmer Skeleton ─────────────────────────────────────────────────

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.elevated,
        highlightColor: AppColors.borderHover,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title lines
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              // Country
              Container(
                height: 10,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              // Badges
              Row(
                children: [
                  Container(
                    height: 18,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 18,
                    width: 44,
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
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppColors.hint.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No scholarships found',
            style: AppTextStyles.title.copyWith(
              color: AppColors.stone,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your filters or search terms',
            style: AppTextStyles.caption.copyWith(color: AppColors.hint),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: 'Clear Filters',
            variant: GlassButtonVariant.secondary,
            onPressed: () {
              _searchController.clear();
              ref.read(browseFiltersProvider.notifier).clearFilters();
            },
          ),
        ],
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.error.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(scholarshipsProvider),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Date Format Helper ───────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

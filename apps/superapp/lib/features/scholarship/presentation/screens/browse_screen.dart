// â”€â”€â”€ Browse Scholarship Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/scholarship_model.dart';
import '../../data/repository/scholarship_repository.dart';
import '../providers/scholarship_providers.dart';
import '../shared/scholarship_helpers.dart';

// â”€â”€â”€ Browse Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<ScholarshipModel> _items = [];
  int _total = 0;
  int _page = 1;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(1));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // â”€â”€â”€ Filter helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  ScholarshipFilters _buildFilters(BrowseFilters f,
      {required int page, int limit = 20}) {
    return ScholarshipFilters(
      q: f.search.isNotEmpty ? f.search : null,
      level: f.level != 'All' ? f.level : null,
      country: f.country != 'All' ? f.country : null,
      fundingType: f.funding != 'All' ? f.funding : null,
      sortBy: f.sortBy.apiValue,
      sortOrder: f.sortOrder.apiValue,
      deadlineDays: f.deadlineDays,
      page: page,
      limit: limit,
    );
  }

  int _activeFilterCount(BrowseFilters f) {
    int count = 0;
    if (f.search.isNotEmpty) count++;
    if (f.level != 'All') count++;
    if (f.country != 'All') count++;
    if (f.funding != 'All') count++;
    if (f.deadlineDays != null) count++;
    return count;
  }

  // â”€â”€â”€ Pagination â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadPage(int page) async {
    if (page == 1) {
      setState(() {
        _isInitialLoading = true;
        _error = null;
        _items = [];
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = ref.read(scholarshipRepositoryProvider);
      final filters = ref.read(browseFiltersProvider);
      final result = await repo.searchScholarships(
          _buildFilters(filters, page: page));

      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _items = result.data;
        } else {
          _items.addAll(result.data);
        }
        _total = result.total;
        _hasMore = _items.length < _total && result.data.length >= 20;
        _page = page;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) {
        _loadPage(_page + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset pagination when filters change
    ref.listen<BrowseFilters>(browseFiltersProvider, (prev, next) {
      if (prev != next && _items.isNotEmpty) {
        _loadPage(1);
      }
    });

    final filters = ref.watch(browseFiltersProvider);

    return GradientBackground(
      child: Column(
        children: [
          // â”€â”€ Search Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

          // â”€â”€ Filter Chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
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
                ..._chipGroup(
                  context,
                  ref,
                  filters,
                  label: 'Country',
                  options: ref.watch(allCountryOptionsProvider),
                  selected: filters.country,
                  onSelect: (v) =>
                      ref.read(browseFiltersProvider.notifier).setCountry(v),
                ),
                const SizedBox(width: 8),
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

          // â”€â”€ Sort Bar + Active Filter Badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                // Sort dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ScholarshipSort>(
                      value: filters.sortBy,
                      dropdownColor: AppColors.surface,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.ink,
                        fontSize: 11,
                      ),
                      items: ScholarshipSort.values.map((sort) {
                        return DropdownMenuItem(
                          value: sort,
                          child: Text(
                            sort.label,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.ink,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(browseFiltersProvider.notifier)
                              .setSortBy(v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // ASC/DESC toggle
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final newOrder =
                            filters.sortOrder == ScholarshipSortOrder.desc
                                ? ScholarshipSortOrder.asc
                                : ScholarshipSortOrder.desc;
                        ref
                            .read(browseFiltersProvider.notifier)
                            .setSortOrder(newOrder);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              filters.sortOrder == ScholarshipSortOrder.desc
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 12,
                              color: AppColors.stone,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              filters.sortOrder == ScholarshipSortOrder.desc
                                  ? 'Newest'
                                  : 'Oldest',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.stone,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Active filter count badge
                if (filters.hasActiveFilters)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref
                          .read(browseFiltersProvider.notifier)
                          .clearFilters();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Clear All (${_activeFilterCount(filters)})',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // â”€â”€ Result Count â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (!_isInitialLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_total scholarship${_total == 1 ? '' : 's'} found',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.stone,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // â”€â”€ LPDP Entry Point â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildLpdpEntryCard(),

          // â”€â”€ Main Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // â”€â”€â”€ LPDP Entry Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildLpdpEntryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.go(AppRoutes.lpdp),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LPDP Unggulan',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '17 partner universities Â· 8 strategic fields',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.stone,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Content Router â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildContent() {
    if (_isInitialLoading) return _buildSkeletonGrid();
    if (_error != null) return _buildError(_error!);
    if (_items.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: () => _loadPage(1),
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return _buildLoadingIndicator();
          }
          return _buildCard(_items[index]);
        },
      ),
    );
  }

  // â”€â”€â”€ Bottom Loading Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Chip Group Builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
            selectedColor: AppColors.accent.withValues(alpha: 0.25),
            backgroundColor: AppColors.elevated,
            side: BorderSide(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.5)
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

  // â”€â”€â”€ Scholarship Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildCard(ScholarshipModel s) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.go(AppRoutes.scholarshipDetailFor(s.id)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Text(
                  s.title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                    countryFlag(s.country),
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
                  ...s.level.map(
                    (l) => ScholarshipLevelBadge(level: l),
                  ),
                  const SizedBox(width: 2),
                  ScholarshipFundingBadge(fundingType: s.fundingType),
                ],
              ),

              // Deadline
              if (s.deadline != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 10, color: AppColors.hint),
                    const SizedBox(width: 3),
                    Text(
                      'Due ${formatDate(s.deadline!)}',
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

          // Deadline urgency badge (top-right)
          if (s.deadline != null && s.deadline!.deadlineInfo.isUrgent)
            Positioned(
              top: 0,
              right: 0,
              child: DeadlineUrgencyBadge(info: s.deadline!.deadlineInfo),
            ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Skeleton Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
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
                width: 100,
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
                    height: 16,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 16,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Deadline skeleton
              Container(
                height: 8,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEmpty() {
    return Center(
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

  // â”€â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              'Something went wrong',
              style: AppTextStyles.title.copyWith(
                color: AppColors.stone,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
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
              onPressed: () => _loadPage(1),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/router/app_routes.dart';
import '../../data/models/models.dart';
import '../providers/fashion_providers.dart';
import '../widgets/color_swatch_row.dart';

const _categories = [
  'Tops', 'Bottoms', 'Dresses', 'Outerwear',
  'Shoes', 'Accessories', 'Activewear', 'Underwear',
];
const _seasons = ['spring', 'summer', 'autumn', 'winter', 'all-season'];

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isLoading = true;
  String? _error;
  List<ClothingItemModel> _items = [];
  final _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedSeasons = {};
  int? _selectedWornBracket;

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _selectedSeasons.isNotEmpty ||
      _selectedWornBracket != null;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(fashionApiClientProvider);
      final response = await api.getWardrobe(page: 1, limit: 200);
      setState(() {
        _items = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return GlassBox(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.borderHover,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Filter Wardrobe',
                          style: AppTextStyles.headline.copyWith(fontSize: 18)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedCategories.clear();
                            _selectedSeasons.clear();
                            _selectedWornBracket = null;
                          });
                          setState(() {});
                        },
                        child: Text('Reset All',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const GlassDivider(),
                  const SizedBox(height: 16),
                  const GlassFieldLabel('CATEGORIES'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSel = _selectedCategories.contains(cat);
                      return FilterChip(
                        label: Text(cat,
                            style: AppTextStyles.caption.copyWith(
                              color: isSel ? AppColors.accent : AppColors.stone,
                            )),
                        selected: isSel,
                        showCheckmark: false,
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              _selectedCategories.add(cat);
                            } else {
                              _selectedCategories.remove(cat);
                            }
                          });
                          setState(() {});
                        },
                        backgroundColor: AppColors.surfaceAlt,
                        selectedColor: AppColors.accent.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(
                          color: isSel
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const GlassFieldLabel('SEASONS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _seasons.map((s) {
                      final isSel = _selectedSeasons.contains(s);
                      return FilterChip(
                        label: Text(s,
                            style: AppTextStyles.caption.copyWith(
                              color: isSel ? AppColors.accent : AppColors.stone,
                            )),
                        selected: isSel,
                        showCheckmark: false,
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              _selectedSeasons.add(s);
                            } else {
                              _selectedSeasons.remove(s);
                            }
                          });
                          setState(() {});
                        },
                        backgroundColor: AppColors.surfaceAlt,
                        selectedColor: AppColors.accent.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(
                          color: isSel
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const GlassFieldLabel('WORN STATUS'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _WornPill(
                        label: 'Any',
                        selected: _selectedWornBracket == null,
                        onTap: () {
                          setSheetState(() => _selectedWornBracket = null);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _WornPill(
                        label: 'Unworn',
                        selected: _selectedWornBracket == 0,
                        onTap: () {
                          setSheetState(() => _selectedWornBracket = 0);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _WornPill(
                        label: '1-5x',
                        selected: _selectedWornBracket == 1,
                        onTap: () {
                          setSheetState(() => _selectedWornBracket = 1);
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _WornPill(
                        label: '5+',
                        selected: _selectedWornBracket == 2,
                        onTap: () {
                          setSheetState(() => _selectedWornBracket = 2);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<ClothingItemModel> _filterItems(List<ClothingItemModel> items) {
    final q = _searchQuery.toLowerCase();
    return items.where((item) {
      if (q.isNotEmpty) {
        final matchesSearch = item.name.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q) ||
            (item.brand?.toLowerCase().contains(q) ?? false);
        if (!matchesSearch) return false;
      }
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(item.category)) {
        return false;
      }
      if (_selectedSeasons.isNotEmpty &&
          item.seasonTags.every((t) => !_selectedSeasons.contains(t))) {
        return false;
      }
      if (_selectedWornBracket != null) {
        if (_selectedWornBracket == 0 && item.timesWorn > 0) return false;
        if (_selectedWornBracket == 1 &&
            (item.timesWorn < 1 || item.timesWorn > 5)) {
          return false;
        }
        if (_selectedWornBracket == 2 && item.timesWorn < 6) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AuroraMeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: _isSearching ? null : 'Wardrobe',
        titleWidget: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.body.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search itemsâ€¦',
                  hintStyle: AppTextStyles.caption,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              size: 22,
              color: AppColors.stone,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: _hasActiveFilters
                ? const Badge(
                    smallSize: 8,
                    child: Icon(Icons.filter_list,
                        size: 20, color: AppColors.accent),
                  )
                : const Icon(Icons.filter_list,
                    size: 20, color: AppColors.stone),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined,
                size: 20, color: AppColors.stone),
            onPressed: () => context.go(AppRoutes.fashionInsights),
            tooltip: 'Analytics',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _AddFab(
        onPressed: () => context.go(AppRoutes.fashionAdd),
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _ShimmerGrid();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Could not load wardrobe',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: 'Retry',
                onPressed: _loadItems,
                icon: Icons.refresh,
                small: true,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filterItems(_items);
    if (_items.isEmpty) {
      return _EmptyWardrobe(onAdd: () => context.go(AppRoutes.fashionAdd));
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('No items match "$_searchQuery"',
                style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return _WardrobeGrid(items: filtered);
  }
}

// â”€â”€ Grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _WardrobeGrid extends StatelessWidget {
  const _WardrobeGrid({required this.items});
  final List<ClothingItemModel> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ClothingCard(item: items[i]),
    );
  }
}

class _ClothingCard extends StatelessWidget {
  const _ClothingCard({required this.item});
  final ClothingItemModel item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.processedImageUrl ?? item.originalImageUrl;

    return GlassCard(
        radius: 14,
        onTap: () => context.go(AppRoutes.fashionDetailFor(item.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: AppColors.elevated),
                            errorWidget: (_, __, ___) =>
                                const _PlaceholderIcon(),
                          )
                        : const _PlaceholderIcon(),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CategoryBadge(item.category),
                  ),
                ],
              ),
            ),

            if (item.dominantColors.isNotEmpty)
              ColorSwatchRow(colors: item.dominantColors),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.brand ?? item.category,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.timesWorn > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ã—${item.timesWorn}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: AppColors.accent,
                            ),
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
}

// â”€â”€ Filter pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _WornPill extends StatelessWidget {
  const _WornPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.accent : AppColors.stone,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.elevated,
      child: const Center(
        child:
            Icon(Icons.checkroom_outlined, size: 40, color: AppColors.hint),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

// â”€â”€ Empty state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: GlassBox(
          radius: 20,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.20)),
                ),
                child: const Icon(Icons.checkroom_outlined,
                    size: 36, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              Text(
                'Your wardrobe is empty',
                style: AppTextStyles.headline.copyWith(fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Add your first item to get started',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GlassButton(
                label: 'Add Item',
                onPressed: onAdd,
                icon: Icons.add,
                small: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Shimmer grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.elevated,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AddFab extends StatefulWidget {
  const _AddFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'ADD ITEM',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

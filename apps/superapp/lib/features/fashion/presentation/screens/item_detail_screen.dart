import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/api/api.dart';
import '../../data/models/models.dart';
import '../providers/fashion_providers.dart';
import '../widgets/color_swatch_row.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ItemDetailLoader(itemId: itemId);
  }
}

class _ItemDetailLoader extends ConsumerStatefulWidget {
  const _ItemDetailLoader({required this.itemId});
  final String itemId;

  @override
  ConsumerState<_ItemDetailLoader> createState() => _ItemDetailLoaderState();
}

class _ItemDetailLoaderState extends ConsumerState<_ItemDetailLoader> {
  ClothingItemModel? _item;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(fashionApiClientProvider);
      final item = await api.getItem(widget.itemId);
      if (mounted) {
        setState(() {
          _item = item;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (_error != null || _item == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Could not load item',
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Item not found',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                GlassButton(
                  label: 'Retry',
                  onPressed: _loadItem,
                  icon: Icons.refresh,
                  small: true,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final api = ref.read(fashionApiClientProvider);
    return _ItemDetailContent(item: _item!, api: api);
  }
}

class _ItemDetailContent extends StatelessWidget {
  const _ItemDetailContent({required this.item, required this.api});
  final ClothingItemModel item;
  final FashionApiClient api;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.processedImageUrl ?? item.originalImageUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // â”€â”€ Collapsible hero image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: AppColors.canvas,
            foregroundColor: AppColors.ink,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: AppColors.surface),
                          errorWidget: (_, __, ___) => Container(
                              color: AppColors.surface),
                        )
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.checkroom_outlined,
                              size: 80, color: AppColors.hint),
                        ),
                  // Gradient fade at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.canvas,
                            AppColors.canvas.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              onPressed: () => context.go(AppRoutes.fashion),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),

          // â”€â”€ Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (item.dominantColors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GlassBox(
                      radius: 12,
                      padding: const EdgeInsets.all(12),
                      child: ColorSwatchRow(colors: item.dominantColors),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Name card
                  GlassBox(
                    radius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(item.name,
                                  style: AppTextStyles.headline),
                            ),
                            const SizedBox(width: 10),
                            GlassBadge(item.category, accent: true),
                          ],
                        ),
                        if (item.brand != null) ...[
                          const SizedBox(height: 4),
                          Text(item.brand!, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                          child: _StatBox(
                        value: '${item.timesWorn}',
                        label: 'TIMES WORN',
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                        value: item.lastWornAt != null
                            ? '${item.lastWornAt!.day}/${item.lastWornAt!.month}'
                            : 'â€”',
                        label: 'LAST WORN',
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                        value: item.seasonTags.isEmpty
                            ? 'â€”'
                            : item.seasonTags.first,
                        label: 'SEASON',
                      )),
                    ],
                  ),

                  const SizedBox(height: 20),

                  GlassButton(
                    label: 'Mark as Worn Today',
                      onPressed: () async {
                      try {
                        await api.markWorn(item.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Logged as worn today')),
                          );
                          // Reload item detail to refresh counts
                          context.go(AppRoutes.fashion);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    variant: GlassButtonVariant.secondary,
                    icon: Icons.done_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassBox(
          radius: 20,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delete item?', style: AppTextStyles.headline),
              const SizedBox(height: 10),
              Text(
                'This will permanently remove the item from your wardrobe.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context, false),
                      variant: GlassButtonVariant.ghost,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Delete',
                      onPressed: () => Navigator.pop(context, true),
                      variant: GlassButtonVariant.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await api.deleteItem(item.id);
        if (context.mounted) context.go(AppRoutes.fashion);
      } catch (e) {
        // Error handled silently; item still removed from local list
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 12,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTextStyles.headline.copyWith(fontSize: 22),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                color: AppColors.hint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

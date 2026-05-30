import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../data/models/models.dart';
import '../providers/ootd_notifier.dart';
import '../providers/tryon_notifier.dart';
import 'tryon_result_screen.dart';

class TryonScreen extends ConsumerStatefulWidget {
  const TryonScreen({super.key, this.initialItemId});
  final String? initialItemId;

  @override
  ConsumerState<TryonScreen> createState() => _TryonScreenState();
}

class _TryonScreenState extends ConsumerState<TryonScreen> {
  bool _showGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tryonNotifierProvider.notifier).loadHistory();
    });
  }

  void _precacheGalleryImages(List<TryonHistoryItem> items) {
    for (final item in items.take(10)) {
      if (item.resultImageUrl.isNotEmpty) {
        precacheImage(
          NetworkImage(item.resultImageUrl),
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tryonState = ref.watch(tryonNotifierProvider);
    final wardrobeAsync = ref.watch(wardrobeItemsProvider);

    ref.listen(tryonNotifierProvider, (_, next) {
      if (next.phase == TryonPhase.done && next.resultImageUrl != null) {
        setState(() => _showGallery = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _TryonResultRedirect(),
          ),
        );
      }
    });

    final isProcessing = tryonState.phase == TryonPhase.uploading ||
        tryonState.phase == TryonPhase.processing;

    // Precache gallery images when showing gallery
    if (_showGallery && tryonState.history.isNotEmpty) {
      _precacheGalleryImages(tryonState.history);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: _showGallery ? 'Try-On Gallery' : 'Virtual Try-On',
        actions: [
          if (tryonState.history.isNotEmpty)
            IconButton(
              icon: Icon(
                _showGallery
                    ? Icons.add_a_photo_outlined
                    : Icons.photo_library_outlined,
                size: 20,
                color: AppColors.stone,
              ),
              onPressed: () => setState(() => _showGallery = !_showGallery),
              tooltip: _showGallery ? 'New Try-On' : 'Gallery',
            ),
        ],
      ),
      body: _showGallery
          ? _buildGallery(context, tryonState)
          : _buildGenerate(context, tryonState, wardrobeAsync, isProcessing),
    );
  }

  Widget _buildGenerate(BuildContext context, TryonState tryonState,
      AsyncValue<List<ClothingItemModel>> wardrobeAsync, bool isProcessing) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassBox(
                radius: 16,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepHeader(step: '01', label: 'SELECT GARMENT'),
                    const SizedBox(height: 14),
                    wardrobeAsync.when(
                      loading: () => const SizedBox(
                        height: 100,
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent)),
                      ),
                      error: (e, _) => Text('Error: $e',
                          style: AppTextStyles.caption),
                      data: (items) => _GarmentSelector(
                        items: items,
                        selectedId: tryonState.garmentItemId ??
                            widget.initialItemId,
                        onSelect: (item) {
                          final url = item.processedImageUrl ??
                              item.originalImageUrl ?? '';
                          ref
                              .read(tryonNotifierProvider.notifier)
                              .setGarment(item.id, url);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassBox(
                radius: 16,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepHeader(step: '02', label: 'YOUR PHOTO'),
                    const SizedBox(height: 14),
                    _PersonPhotoSection(
                      personFile: tryonState.personFile,
                      onPick: () => ref
                          .read(tryonNotifierProvider.notifier)
                          .pickPersonPhoto(),
                    ),
                  ],
                ),
              ),
              if (tryonState.phase == TryonPhase.error) ...[
                const SizedBox(height: 12),
                GlassBox(
                  radius: 12,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tryonState.error ?? 'Unknown error',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GlassButton(
                label: 'Run Try-On',
                onPressed: (tryonState.garmentImageUrl != null &&
                        tryonState.personFile != null)
                    ? () => ref.read(tryonNotifierProvider.notifier).run()
                    : null,
                isLoading: isProcessing,
                icon: Icons.auto_fix_high_outlined,
              ),
              if (tryonState.garmentImageUrl == null ||
                  tryonState.personFile == null) ...[
                const SizedBox(height: 10),
                Text(
                  tryonState.garmentImageUrl == null
                      ? 'Select a garment above to continue'
                      : 'Add your photo to continue',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        // Inline loading overlay
        if (isProcessing)
          Container(
            color: AppColors.canvas.withOpacity(0.80),
            child: Center(
              child: GlassBox(
                radius: 16,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tryonState.statusMessage ?? 'Processing...',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGallery(BuildContext context, TryonState tryonState) {
    if (tryonState.isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.accent),
      );
    }

    if (tryonState.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('No try-on history yet', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() => _showGallery = false),
              child: Text('Create your first try-on',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: tryonState.history.length,
      itemBuilder: (_, i) {
        final item = tryonState.history[i];
        return GestureDetector(
          onTap: () => _showHistoryDetail(context, item),
          child: GlassCard(
            radius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(13)),
                    child: CachedNetworkImage(
                      imageUrl: item.resultImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.elevated),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.elevated,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.hint),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.garmentName ?? 'Unknown',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.garmentCategory ?? '',
                        style:
                            AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistoryDetail(BuildContext context, TryonHistoryItem item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassBox(
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.resultImageUrl,
                  fit: BoxFit.contain,
                  height: 300,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: AppColors.elevated,
                    child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 300,
                    color: AppColors.elevated,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.hint),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                item.garmentName ?? 'Try-On Result',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              if (item.garmentCategory != null)
                Text(
                  item.garmentCategory!,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 6),
              Text(
                '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                style: AppTextStyles.caption.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Delete',
                      onPressed: () {
                        ref
                            .read(tryonNotifierProvider.notifier)
                            .deleteHistoryItem(item.id);
                        Navigator.pop(context);
                      },
                      variant: GlassButtonVariant.danger,
                      icon: Icons.delete_outline,
                      small: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Share',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Share feature coming soon')),
                        );
                      },
                      variant: GlassButtonVariant.secondary,
                      icon: Icons.share_outlined,
                      small: true,
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
}

// ── Components ────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.label});
  final String step;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: Center(
            child: Text(
              step,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _GlassFieldLabel(label),
      ],
    );
  }
}

class _GarmentSelector extends StatelessWidget {
  const _GarmentSelector({
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ClothingItemModel> items;
  final String? selectedId;
  final void Function(ClothingItemModel) onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Your wardrobe is empty',
              style: AppTextStyles.caption),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          final imageUrl = item.processedImageUrl ?? item.originalImageUrl;
          final isSelected = item.id == selectedId;

          return GestureDetector(
            onTap: () => onSelect(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.border,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.20),
                          blurRadius: 12,
                          spreadRadius: 0,
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: AppColors.elevated,
                        child: const Icon(Icons.checkroom_outlined,
                            color: AppColors.hint),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PersonPhotoSection extends StatelessWidget {
  const _PersonPhotoSection(
      {required this.personFile, required this.onPick});
  final File? personFile;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: personFile != null
                ? AppColors.accent
                : AppColors.border,
            width: personFile != null ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: personFile != null
            ? Image.file(personFile!,
                fit: BoxFit.cover, width: double.infinity)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.10),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.20)),
                    ),
                    child: const Icon(Icons.person_add_outlined,
                        size: 22, color: AppColors.accent),
                  ),
                  const SizedBox(height: 12),
                  Text('Tap to select your photo',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text('Full-body shot works best',
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
      ),
    );
  }
}

class _GlassFieldLabel extends StatelessWidget {
  const _GlassFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.label.copyWith(
        color: AppColors.hint,
        letterSpacing: 1.2,
        fontSize: 11,
      ),
    );
  }
}

/// Simple redirect page that shows the try-on result and provides navigation.
class _TryonResultRedirect extends ConsumerWidget {
  const _TryonResultRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate to the full result screen after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TryonResultScreen(),
          ),
        );
      }
    });

    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.accent),
      ),
    );
  }
}



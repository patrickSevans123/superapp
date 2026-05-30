import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/tryon_notifier.dart';

class TryonResultScreen extends ConsumerWidget {
  const TryonResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tryonState = ref.watch(tryonNotifierProvider);
    final resultUrl = tryonState.resultImageUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Result image ──────────────────────────────────────────────
          resultUrl != null
              ? CachedNetworkImage(
                  imageUrl: resultUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined,
                            color: AppColors.hint, size: 52),
                        const SizedBox(height: 14),
                        Text('Could not load result',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                )
              : const Center(
                  child: Text('No result available',
                      style: TextStyle(color: AppColors.hint))),

          // ── Top bar ───────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.canvas.withOpacity(0.90),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'TRY-ON RESULT',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.ink,
                          letterSpacing: 2,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: AppColors.ink),
                      onPressed: resultUrl != null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Share feature coming soon')),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom action bar ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.canvas.withOpacity(0.90),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Try Another',
                        onPressed: () {
                          ref
                              .read(tryonNotifierProvider.notifier)
                              .reset();
                          Navigator.of(context).pop();
                        },
                        variant: GlassButtonVariant.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassButton(
                        label: 'Back',
                        onPressed: () {
                          ref
                              .read(tryonNotifierProvider.notifier)
                              .reset();
                          Navigator.of(context).pop();
                        },
                        icon: Icons.checkroom_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

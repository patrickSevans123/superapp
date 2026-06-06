import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/sub_app/active_sub_app_provider.dart';

/// Modal bottom sheet for picking the active mode.
///
/// Per the product spec the mode switcher must NOT live in the bottom
/// navigation bar — it lives in Profile, so this sheet is the only place
/// the user ever changes the mode. Each mode is rendered as a glassmorphism
/// card with a per-mode accent gradient and a one-line description so the
/// difference between Scholarship / Fashion / Trade is immediately legible.
class ModePickerSheet extends ConsumerWidget {
  const ModePickerSheet({super.key});

  /// Helper for callers: opens the picker as a modal bottom sheet and
  /// applies the user's choice via [activeSubAppProvider]. Returns the
  /// selected mode (or `null` if dismissed).
  static Future<SubApp?> show(BuildContext context) {
    return showModalBottomSheet<SubApp>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const ModePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSubAppProvider);

    return GlassBox(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppAdaptive.borderHover(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose a mode',
              style: AppTextStyles.headline.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'The Home tab will show the selected mode\'s content.',
              style: AppTextStyles.caption.copyWith(
                color: AppAdaptive.stone(context),
              ),
            ),
            const SizedBox(height: 20),
            for (final mode in SubApp.values) ...[
              _ModeCard(
                mode: mode,
                selected: active == mode,
                onTap: () {
                  ref.read(activeSubAppProvider.notifier).setActive(mode);
                  Navigator.of(context).pop(mode);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SubApp mode;
  final bool selected;
  final VoidCallback onTap;

  /// Per-mode accent gradient (aurora-derived). Each mode gets a
  /// distinctive hue so the user can recognise the mode at a glance.
  List<Color> get _gradientColors {
    switch (mode) {
      case SubApp.scholarships:
        return const [AppAccent.auroraViolet, AppAccent.auroraPink];
      case SubApp.fashion:
        return const [AppAccent.auroraPink, AppAccent.auroraViolet];
      case SubApp.trade:
        return const [AppAccent.auroraCyan, AppAccent.auroraViolet];
    }
  }

  IconData get _icon {
    switch (mode) {
      case SubApp.scholarships:
        return Icons.school_rounded;
      case SubApp.fashion:
        return Icons.checkroom_rounded;
      case SubApp.trade:
        return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppAdaptive.accent(context).withValues(alpha: 0.10)
              : AppAdaptive.elevated(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppAdaptive.accent(context).withValues(alpha: 0.55)
                : AppAdaptive.border(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon badge with aurora gradient
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _gradientColors.first.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(_icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: AppTextStyles.title.copyWith(
                      color: AppAdaptive.ink(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppAdaptive.stone(context),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 22)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: AppAdaptive.hint(context),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

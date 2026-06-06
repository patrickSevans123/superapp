import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/sub_app/active_sub_app_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';

/// Maps each [SubApp] to a short description shown under the tile.
const _kDescriptions = <SubApp, String>{
  SubApp.scholarships: 'Browse & track scholarship opportunities',
  SubApp.fashion: 'AI-powered wardrobe & style recommendations',
  SubApp.trade: 'Trading dashboard, signals & portfolio',
};

/// Returns a time-of-day greeting: "Good morning/afternoon/evening".
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// The launcher / home screen of the superapp.
///
/// Displays a greeting and a grid of sub-app tiles. Tapping a tile activates
/// the corresponding [SubApp] via [activeSubAppProvider], which causes the
/// router to swap the entire UI for that sub-app.
class LauncherScreen extends ConsumerWidget {
  const LauncherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          titleWidget: Text(
            'SuperApp',
            style: AppTextStyles.title.copyWith(
              fontSize: 16,
              color: AppAdaptive.ink(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            // ── Theme toggle ──────────────────────────────────────────
            IconButton(
              tooltip: 'Toggle theme',
              icon: Icon(
                switch (themeMode) {
                  ThemeMode.dark => Icons.dark_mode_rounded,
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.system => Icons.brightness_auto_rounded,
                },
                color: AppAdaptive.accent(context),
              ),
              onPressed: () =>
                  ref.read(themeModeProvider.notifier).cycle(),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Greeting ───────────────────────────────────────────
                Text(
                  '${_greeting()}, Patri',
                  style: AppTextStyles.headline.copyWith(
                    color: AppAdaptive.ink(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick an app to get started',
                  style: AppTextStyles.body.copyWith(
                    color: AppAdaptive.stone(context),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sub-app grid ───────────────────────────────────────
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1,
                    ),
                    itemCount: SubApp.values.length,
                    itemBuilder: (context, index) {
                      final subApp = SubApp.values[index];
                      return _SubAppTile(subApp: subApp);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ── Quick-action bar ───────────────────────────────────
                const _QuickActions(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-app tile ──────────────────────────────────────────────────────────

class _SubAppTile extends ConsumerWidget {
  const _SubAppTile({required this.subApp});

  final SubApp subApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = _kDescriptions[subApp] ?? '';

    return GlassCard(
      onTap: () =>
          ref.read(activeSubAppProvider.notifier).setActive(subApp),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(subApp.icon, size: 36, color: AppAdaptive.accent(context)),
          const SizedBox(height: 12),
          Text(
            subApp.label,
            style: AppTextStyles.title.copyWith(
              color: AppAdaptive.ink(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              color: AppAdaptive.stone(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Quick-action row ──────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QuickActionChip(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications — coming soon'),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        _QuickActionChip(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings — coming soon'),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Small circular glass button used for quick actions.
class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppAdaptive.surface(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppAdaptive.border(context)),
            ),
            child: Icon(icon, size: 20, color: AppAdaptive.accent(context)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppAdaptive.stone(context),
            ),
          ),
        ],
      ),
    );
  }
}

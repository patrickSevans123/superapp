import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/sub_app/active_sub_app_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/mode_picker_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_menu_tile.dart';

/// Main profile landing screen.
///
/// Displays the user's avatar, name, email, the active-mode card (which
/// is the *only* place in the app where the user can switch the mode —
/// per the product spec the bottom nav is intentionally mode-agnostic),
/// stats row, and a menu list for profile-related actions.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    // Re-fetch whenever the userId becomes available (e.g. cold start
    // race where the profile screen mounts before [loadToken] finishes
    // hydrating the JWT from secure storage).
    ref.listenManual<String?>(currentUserIdProvider, (prev, next) {
      if (next != null && (prev == null || prev != next) && mounted) {
        _loadProfile();
      }
    });
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }
      final repo = ref.read(profileRepositoryProvider);
      final user = await repo.getProfile(userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraMeshBackground(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
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
                'Could not load profile',
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
                onPressed: _loadProfile,
                icon: Icons.refresh,
                small: true,
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          const SizedBox(height: 4),

          // ─── Profile Header ───────────────────────────────────────
          ProfileHeader(user: user),

          const SizedBox(height: 16),

          // ─── Active Mode card (the "hidden" mode switcher) ────────
          // Per product spec the bottom nav must NOT expose mode tabs,
          // so this is the only place the user can switch the active
          // mode. The card shows the current mode + a chevron to make
          // it discoverable without being intrusive.
          const _ActiveModeCard(),

          const SizedBox(height: 16),

          // ─── Stats Row ─────────────────────────────────────────────
          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Active Plans',
                  value: '—',
                  icon: Icons.assignment,
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: _StatCard(
                  label: 'Contests',
                  value: '—',
                  icon: Icons.emoji_events,
                  color: AppColors.warning,
                ),
              ),
              Expanded(
                child: _StatCard(
                  label: 'Saved',
                  value: '—',
                  icon: Icons.bookmark,
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Menu Items ───────────────────────────────────────────
          ProfileMenuTile(
            icon: Icons.person_rounded,
            title: 'Edit Profile',
            onTap: () => context.push(AppRoutes.profileEdit),
          ),

          ProfileMenuTile(
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved Scholarships',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved Scholarships — coming soon')),
              );
            },
          ),

          ProfileMenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () => context.push(AppRoutes.profileSettings),
          ),

          const SizedBox(height: 8),

          ProfileMenuTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            iconColor: AppColors.error,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logout — coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Active Mode" card. Tapping opens the [ModePickerSheet] so the user
/// can switch between Scholarship / Fashion / Trade. The card is the
/// *only* mode UI in the app, fulfilling the "hidden in profile" spec.
class _ActiveModeCard extends ConsumerWidget {
  const _ActiveModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeSubAppProvider);
    final label = mode?.label ?? 'Pick a mode';
    final description = mode?.description ?? 'Tap to choose what Home shows';
    final icon = mode?.icon ?? Icons.swap_horiz_rounded;

    // Per-mode gradient: scholarship=violet, fashion=pink, trade=cyan.
    final List<Color> gradientColors = switch (mode) {
      SubApp.scholarships => const [AppAccent.auroraViolet, AppAccent.auroraPink],
      SubApp.fashion => const [AppAccent.auroraPink, AppAccent.auroraCyan],
      SubApp.trade => const [AppAccent.auroraCyan, AppAccent.auroraViolet],
      null => const [AppColors.elevated, AppColors.elevated],
    };

    return GlassCard.elevated(
      onTap: () => ModePickerSheet.show(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Mode',
                  style: AppTextStyles.caption.copyWith(
                    color: AppAdaptive.hint(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.title.copyWith(
                    color: AppAdaptive.ink(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppAdaptive.stone(context),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppAdaptive.hint(context),
          ),
        ],
      ),
    );
  }
}

/// A small stat card used in the profile stats row.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      margin: const EdgeInsets.all(3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppAdaptive.stone(context),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

import '../providers/profile_providers.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_menu_tile.dart';

/// Main profile landing screen.
///
/// Displays the user's avatar, name, email, stats cards,
/// and a menu list for profile-related actions.
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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // TODO: Replace with actual authenticated user ID from Supabase auth
      const userId = 'current-user-id';
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
    return GradientBackground(
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
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 8),

          // ─── Profile Header ────────────────────────────────────
          ProfileHeader(user: user),

          // ─── Stats Row ─────────────────────────────────────────
          Row(
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

          const SizedBox(height: 16),

          // ─── Menu Items ────────────────────────────────────────
          ProfileMenuTile(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () => context.push('/profile/edit'),
          ),

          ProfileMenuTile(
            icon: Icons.bookmark_outline,
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
            onTap: () => context.push('/profile/settings'),
          ),

          ProfileMenuTile(
            icon: Icons.logout,
            title: 'Logout',
            iconColor: AppColors.error,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logout — coming soon')),
              );
            },
          ),

          const SizedBox(height: 24),
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
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

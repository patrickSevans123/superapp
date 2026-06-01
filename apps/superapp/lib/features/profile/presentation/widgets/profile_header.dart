import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

/// Displays the user's avatar, display name, email, and premium status badge.
class ProfileHeader extends StatelessWidget {
  final UserModel user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // ─── Avatar ────────────────────────────────────────────
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.accent.withValues(alpha: 0.20),
            backgroundImage:
                user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),

          // ─── Display Name ──────────────────────────────────────
          Text(
            user.displayName ?? 'User',
            style: AppTextStyles.display.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // ─── Email ─────────────────────────────────────────────
          Text(
            user.email,
            style: AppTextStyles.body.copyWith(color: AppColors.stone),
            textAlign: TextAlign.center,
          ),

          // ─── Premium Badge ─────────────────────────────────────
          if (user.isPremium) ...[
            const SizedBox(height: 10),
            const GlassBadge('Premium', accent: true),
          ],
        ],
      ),
    );
  }

  String get _initials {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      final parts = user.displayName!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    return user.email[0].toUpperCase();
  }
}

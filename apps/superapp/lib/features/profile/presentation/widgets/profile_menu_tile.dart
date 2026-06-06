import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';

/// A menu tile for the profile screen. Wrapped in a [GlassCard] with a
/// leading icon, title, and trailing chevron.
class ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;

  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(
            icon,
            color: iconColor ?? AppColors.accent,
            size: 22,
          ),
          title: Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.hint,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          dense: true,
        ),
      ),
    );
  }
}

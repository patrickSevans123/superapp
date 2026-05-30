import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

import '../providers/profile_providers.dart';

/// Edit profile screen.
///
/// Allows the user to update their display name and avatar photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  UserModel? _user;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
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
        _displayNameController.text = user.displayName ?? '';
        _avatarUrl = user.avatarUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // TODO: Replace with actual authenticated user ID from Supabase auth
      const userId = 'current-user-id';
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(
        userId,
        displayName: _displayNameController.text.trim(),
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: GlassScaffold(
        appBar: GlassAppBar(
          title: 'Edit Profile',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),

          // ─── Avatar Section ────────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.20),
                  backgroundImage:
                      _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? NetworkImage(_avatarUrl!)
                          : null,
                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                      ? Text(
                          _initials(user),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Change Photo',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Photo picker — coming soon'),
                      ),
                    );
                  },
                  icon: Icons.camera_alt_outlined,
                  variant: GlassButtonVariant.secondary,
                  small: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─── Display Name ──────────────────────────────────────
          GlassFieldLabel('DISPLAY NAME'),
          const SizedBox(height: 8),
          GlassTextField(
            controller: _displayNameController,
            hintText: 'Enter your display name',
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value != null && value.trim().length > 50) {
                return 'Display name must be 50 characters or less';
              }
              return null;
            },
          ),

          const SizedBox(height: 8),

          // ─── Email (read-only) ─────────────────────────────────
          GlassFieldLabel('EMAIL'),
          const SizedBox(height: 8),
          GlassTextField(
            hintText: user.email,
            prefixIcon: Icons.email_outlined,
          ),

          const SizedBox(height: 32),

          // ─── Save Button ───────────────────────────────────────
          GlassButton(
            label: 'Save Changes',
            onPressed: _isSaving ? null : _saveProfile,
            icon: Icons.check,
            isLoading: _isSaving,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _initials(UserModel user) {
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

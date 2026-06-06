import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/pin/pin_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/update/update_dialog.dart';
import '../../../../core/update/update_provider.dart';
import '../../../pin/presentation/screens/pin_input_screen.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(settingsStateProvider.notifier).loadSettings('current-user-id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsStateProvider);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const GlassAppBar(title: 'Settings'),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? Center(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Account section
                      const _SectionHeader(title: 'Account'),
                      const SizedBox(height: 8),
                      GlassCard(
                        child: Column(
                          children: [
                            _AccountRow(
                              label: 'Name',
                              value:
                                  state.account?['display_name']?.toString() ??
                                      '—',
                            ),
                            const Divider(),
                            _AccountRow(
                              label: 'Email',
                              value: state.account?['email']?.toString() ?? '—',
                            ),
                            const Divider(),
                            _AccountRow(
                              label: 'Premium',
                              value:
                                  (state.account?['is_premium'] == true)
                                      ? 'Yes'
                                      : 'No',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Appearance section
                      const _SectionHeader(title: 'Appearance'),
                      const SizedBox(height: 8),
                      const _ThemeToggleCard(),
                      const SizedBox(height: 24),

                      // Security section
                      const _SectionHeader(title: 'Security'),
                      const SizedBox(height: 8),
                      const _PinLockCard(),
                      const SizedBox(height: 24),

                      // Notifications section
                      const _SectionHeader(title: 'Notifications'),
                      const SizedBox(height: 8),
                      GlassCard(
                        child: ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notification Preferences'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push(AppRoutes.profileNotifications),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App section
                      if (!kIsWeb) ...[
                        const _SectionHeader(title: 'App'),
                        const SizedBox(height: 8),
                        GlassCard(
                          child: Column(
                            children: [
                              _AppInfoRow(),
                              const Divider(),
                              _CheckForUpdateRow(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Sign out
                      GlassCard(
                        child: ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: AppColors.error,
                          ),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.error),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sign Out — coming soon'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String label;
  final String value;
  const _AccountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.stone),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Displays the current app version.
class _AppInfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Version', style: TextStyle(color: AppColors.stone)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snapshot) {
              final version = snapshot.data?.version ?? '...';
              final build = snapshot.data?.buildNumber ?? '';
              return Text(
                '$version ($build)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Triggers the in-app update check flow.
class _CheckForUpdateRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    final isChecking = updateState.status == UpdateStatus.checking;

    return ListTile(
      leading: Icon(
        Icons.system_update_rounded,
        color: isChecking ? AppColors.accent : null,
      ),
      title: Text(isChecking ? 'Checking...' : 'Check for Updates'),
      trailing: isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isChecking
          ? null
          : () => showUpdateDialog(context),
    );
  }
}

/// Theme mode toggle card with three options: Light, Dark, System.
class _ThemeToggleCard extends ConsumerWidget {
  const _ThemeToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return GlassCard(
      child: Column(
        children: [
          _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            selected: currentMode == ThemeMode.light,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
          ),
          const Divider(),
          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            selected: currentMode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
          ),
          const Divider(),
          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            label: 'System',
            selected: currentMode == ThemeMode.system,
            onTap: () =>
                ref.read(themeModeProvider.notifier).setMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.accent : null),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: AppColors.accent)
          : Icon(Icons.circle_outlined, color: AppColors.hint),
      onTap: onTap,
    );
  }
}

/// PIN lock toggle and setup card.
class _PinLockCard extends ConsumerWidget {
  const _PinLockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinEnabled = ref.watch(pinEnabledProvider);

    return pinEnabled.when(
      loading: () => const GlassCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (enabled) => GlassCard(
        child: Column(
          children: [
            SwitchListTile(
              secondary: Icon(
                enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: enabled ? AppColors.accent : null,
              ),
              title: const Text('App Lock (PIN)'),
              subtitle: Text(
                enabled ? 'Required on every app launch' : 'Disabled',
                style: TextStyle(
                  color: enabled ? AppColors.success : AppColors.stone,
                  fontSize: 12,
                ),
              ),
              value: enabled,
              activeColor: AppColors.accent,
              onChanged: (value) async {
                if (value) {
                  // Enable — show setup flow.
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const PinInputScreen(setupMode: true),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(pinEnabledProvider);
                  }
                } else {
                  // Disable — confirm then clear.
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Disable App Lock?'),
                      content: const Text(
                        'Your PIN will be removed. The app will no longer '
                        'require a PIN to open.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Disable',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(pinServiceProvider).clearPin();
                    ref.invalidate(pinEnabledProvider);
                  }
                }
              },
            ),
            if (enabled) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const PinInputScreen(setupMode: true),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

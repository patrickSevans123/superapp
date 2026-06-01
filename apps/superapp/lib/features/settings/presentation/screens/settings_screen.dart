import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
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

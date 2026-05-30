import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/notification_preferences.dart';
import '../providers/settings_providers.dart';
import '../providers/settings_state.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
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
        appBar: const GlassAppBar(title: 'Notification Preferences'),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? Center(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : _buildContent(state),
      ),
    );
  }

  Widget _buildContent(SettingsState state) {
    final prefs = state.preferences ?? const NotificationPreferences();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Notifications'),
        const SizedBox(height: 8),
        GlassCard(
          child: Column(
            children: [
              _buildSwitchTile(
                title: 'TP Hit',
                subtitle: 'When take-profit is triggered',
                value: prefs.tpHit,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(tpHit: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'SL Hit',
                subtitle: 'When stop-loss is triggered',
                value: prefs.slHit,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(slHit: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Price Alert',
                subtitle: 'When monitored price changes',
                value: prefs.priceAlert,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(priceAlert: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'MSCI Announcement',
                subtitle: 'MSCI index changes',
                value: prefs.msciAnnounce,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(msciAnnounce: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'FTSE Notice',
                subtitle: 'FTSE index changes',
                value: prefs.ftseNotice,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(ftseNotice: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'New Report',
                subtitle: 'When a new research report is available',
                value: prefs.newReport,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(newReport: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Plan Created',
                subtitle: 'When a new trade plan is created',
                value: prefs.planCreated,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(planCreated: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Scholarship Alert',
                subtitle: 'New scholarship opportunities',
                value: prefs.scholarshipAlert,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(scholarshipAlert: v),
                ),
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Fashion Alert',
                subtitle: 'Fashion-related notifications',
                value: prefs.fashionAlert,
                onChanged: (v) => _update(
                  state,
                  prefs.copyWith(fashionAlert: v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.stone),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.accent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void _update(SettingsState state, NotificationPreferences newPrefs) {
    ref
        .read(settingsStateProvider.notifier)
        .updatePreferences('current-user-id', newPrefs);
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

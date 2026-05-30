import '../../data/models/notification_preferences.dart';

/// Holds the state for the settings feature.
class SettingsState {
  final Map<String, dynamic>? account;
  final NotificationPreferences? preferences;
  final bool loading;
  final String? error;

  const SettingsState({
    this.account,
    this.preferences,
    this.loading = false,
    this.error,
  });

  SettingsState copyWith({
    Map<String, dynamic>? account,
    NotificationPreferences? preferences,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return SettingsState(
      account: account ?? this.account,
      preferences: preferences ?? this.preferences,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

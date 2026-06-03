import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/api/settings_api_client.dart';
import '../../data/repository/settings_repository.dart';
import '../../data/models/notification_preferences.dart';
import 'settings_state.dart';

/// Provides the [SettingsApiClient] singleton using the shared auth-aware Dio.
final settingsApiClientProvider = Provider<SettingsApiClient>((ref) {
  return SettingsApiClient(dio: ref.watch(authDioProvider));
});

/// Provides the [SettingsRepository] singleton.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.read(settingsApiClientProvider));
});

/// Provides the [SettingsNotifier] and manages [SettingsState].
final settingsStateProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.read(settingsRepositoryProvider));
});

/// Notifier that manages settings state.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const SettingsState());

  /// Loads settings for the given [userId] and updates state.
  Future<void> loadSettings(String userId) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final newState = await _repository.loadSettings(userId);
      state = newState.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  /// Updates notification preferences for the given [userId].
  Future<void> updatePreferences(
      String userId, NotificationPreferences prefs) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final newState =
          await _repository.updateSettings(userId, preferences: prefs.toJson());
      state = newState;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Updates settings for the given [userId] and updates state.
  Future<void> updateSettings(
    String userId, {
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final newState = await _repository.updateSettings(
        userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        preferences: preferences,
      );
      state = newState.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/settings_api_client.dart';
import '../../data/repository/settings_repository.dart';
import '../../data/models/notification_preferences.dart';
import 'settings_state.dart';

/// Base Dio provider for the settings feature.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://100.110.59.78:8080/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Provides the [SettingsApiClient] singleton.
final settingsApiClientProvider = Provider<SettingsApiClient>((ref) {
  return SettingsApiClient(dio: ref.read(dioProvider));
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

import '../api/settings_api_client.dart';
import '../models/notification_preferences.dart';
import '../../presentation/providers/settings_state.dart';

/// Repository that mediates between the [SettingsApiClient] and the rest of
/// the app. Wraps API calls with consistent error handling.
class SettingsRepository {
  final SettingsApiClient _api;

  SettingsRepository(this._api);

  /// Loads the settings for the given [userId] and returns a [SettingsState].
  Future<SettingsState> loadSettings(String userId) async {
    try {
      final data = await _api.getSettings(userId);

      final account = data['account'] as Map<String, dynamic>?;
      final prefsJson = data['preferences'] as Map<String, dynamic>?;

      return SettingsState(
        account: account,
        preferences: prefsJson != null
            ? NotificationPreferences.fromJson(prefsJson)
            : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the settings for the given [userId] and returns the new state.
  Future<SettingsState> updateSettings(
    String userId, {
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final data = await _api.updateSettings(
        userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        preferences: preferences,
      );

      final account = data['account'] as Map<String, dynamic>?;
      final prefsJson = data['preferences'] as Map<String, dynamic>?;

      return SettingsState(
        account: account,
        preferences: prefsJson != null
            ? NotificationPreferences.fromJson(prefsJson)
            : null,
      );
    } catch (e) {
      rethrow;
    }
  }
}

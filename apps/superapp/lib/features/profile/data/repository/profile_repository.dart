import 'package:shared_models/shared_models.dart';

import '../api/profile_api_client.dart';

/// Repository that mediates between the [ProfileApiClient] and the rest of
/// the app. Wraps API calls with consistent error handling.
class ProfileRepository {
  final ProfileApiClient _api;

  ProfileRepository(this._api);

  /// Fetches the user profile for the given [userId].
  Future<UserModel> getProfile(String userId) async {
    try {
      return await _api.getProfile(userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the profile for the given [userId].
  Future<UserModel> updateProfile(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      return await _api.updateProfile(
        userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      rethrow;
    }
  }
}

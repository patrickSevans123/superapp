import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_state.dart';
import '../api/auth_api_client.dart';
import '../models/auth_result.dart';

class AuthRepository {
  final AuthApiClient _api;

  /// Secure storage holds the actual JWT. Keychain on iOS, encrypted
  /// SharedPreferences on Android, libsodium/IndexedDB on web.
  final FlutterSecureStorage _secure;

  /// Plain SharedPreferences is used for the cheap "do we have a token?"
  /// hint that drives the synchronous `hasToken()` check on cold start.
  /// We deliberately do NOT store the JWT in plain prefs.
  final SharedPreferences _prefs;

  AuthRepository(this._api, this._secure, this._prefs);

  Future<AuthResult> register(
      String email, String password, String displayName) async {
    final data = await _api.register(email, password, displayName);
    await _saveToken(data['token'] as String);
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> login(String email, String password) async {
    final data = await _api.login(email, password);
    await _saveToken(data['token'] as String);
    return AuthResult.fromJson(data);
  }

  Future<void> logout() async {
    // Try to blacklist token on server (best-effort — ignore errors)
    final token = await getToken();
    if (token != null) {
      try {
        await _api.logout(token);
      } catch (_) {
        // Server unreachable is fine — still clear local token
      }
    }
    await clearToken();
  }

  Future<String?> getToken() async {
    return _secure.read(key: kAuthTokenKey);
  }

  Future<void> _saveToken(String token) async {
    await _secure.write(key: kAuthTokenKey, value: token);
    // Mirror the existence in plain prefs so `hasToken()` is a cheap
    // synchronous check that doesn't have to hit secure storage on
    // every cold start.
    await _prefs.setBool(kHasSecureTokenKey, true);
  }

  bool hasToken() {
    return _prefs.getBool(kHasSecureTokenKey) ?? false;
  }

  Future<void> clearToken() async {
    await _secure.delete(key: kAuthTokenKey);
    await _prefs.remove(kHasSecureTokenKey);
  }

  /// Attempts to refresh the JWT token. Returns the new token on success,
  /// or `null` if the refresh fails (e.g. the refresh token is also expired).
  Future<String?> tryRefresh(String token) async {
    try {
      final data = await _api.refresh(token);
      final newToken = data['token'] as String;
      await _saveToken(newToken);
      return newToken;
    } catch (_) {
      return null;
    }
  }
}

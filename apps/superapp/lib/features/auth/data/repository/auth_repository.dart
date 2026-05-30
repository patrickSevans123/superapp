import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_api_client.dart';
import '../models/auth_result.dart';

class AuthRepository {
  final AuthApiClient _api;
  final SharedPreferences _prefs;

  AuthRepository(this._api, this._prefs);

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
    await _prefs.remove('auth_token');
  }

  Future<String?> getToken() async {
    return _prefs.getString('auth_token');
  }

  Future<void> _saveToken(String token) async {
    await _prefs.setString('auth_token', token);
  }

  bool hasToken() {
    return _prefs.containsKey('auth_token');
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/auth_api_client.dart';

// ─── Token Provider ──────────────────────────────────────────────────────────

/// Holds the current JWT token in memory. Updated by [AuthNotifier] on
/// login/register/logout.
final authTokenProvider = StateProvider<String?>((ref) => null);

// ─── API Client ──────────────────────────────────────────────────────────────

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  return AuthApiClient();
});

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    Map<String, dynamic>? user,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Auth Notifier ───────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiClient _api;
  final Ref _ref;
  SharedPreferences? _prefs;

  AuthNotifier(this._api, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final token = prefs.getString('auth_token');
    if (token != null) {
      _ref.read(authTokenProvider.notifier).state = token;
      state = state.copyWith(isLoggedIn: true);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final api = _api;
      final prefs = _prefs;
      if (prefs == null) {
        state = state.copyWith(
            isLoading: false, error: 'Storage not initialized');
        return;
      }
      final data = await api.login(email, password);
      final token = data['token'] as String;
      await prefs.setString('auth_token', token);
      _ref.read(authTokenProvider.notifier).state = token;
      state = AuthState(isLoggedIn: true, user: data['user'] as Map<String, dynamic>?);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final api = _api;
      final prefs = _prefs;
      if (prefs == null) {
        state = state.copyWith(
            isLoading: false, error: 'Storage not initialized');
        return;
      }
      final data = await api.register(email, password, displayName);
      final token = data['token'] as String;
      await prefs.setString('auth_token', token);
      _ref.read(authTokenProvider.notifier).state = token;
      state = AuthState(isLoggedIn: true, user: data['user'] as Map<String, dynamic>?);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove('auth_token');
    }
    _ref.read(authTokenProvider.notifier).state = null;
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Auth State Provider ─────────────────────────────────────────────────────

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authApiClientProvider), ref);
});

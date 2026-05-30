import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/auth_api_client.dart';
import '../../data/repository/auth_repository.dart';

// ─── Shared Prefs Provider ───────────────────────────────────────────────────

/// Injected in [main.dart] before [runApp] so that token reads are synchronous
/// (no microtask gap on cold start).
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

// ─── Auth Repository Provider ────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(authApiClientProvider),
    ref.read(sharedPrefsProvider),
  );
});

// ─── API Client ──────────────────────────────────────────────────────────────

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  return AuthApiClient();
});

// ─── Auth State ──────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.token,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? token,
    Map<String, dynamic>? user,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        token: token ?? this.token,
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Auth Notifier ───────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  /// Loads the initial token synchronously from [SharedPreferences] (which was
  /// pre-loaded in [main.dart]) – no microtask gap, no cold-start race.
  AuthNotifier(this._repo, SharedPreferences prefs)
      : super(_loadInitialState(prefs));

  static AuthState _loadInitialState(SharedPreferences prefs) {
    final token = prefs.getString('auth_token');
    if (token != null) {
      return AuthState(isLoggedIn: true, token: token);
    }
    return const AuthState();
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.login(email, password);
      state = AuthState(
        isLoggedIn: true,
        token: result.token,
        user: result.user,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.register(email, password, displayName);
      state = AuthState(
        isLoggedIn: true,
        token: result.token,
        user: result.user,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  /// Attempts a token refresh. Returns `true` if a new token was obtained.
  Future<bool> tryRefresh() async {
    if (state.token == null) return false;
    final newToken = await _repo.tryRefresh(state.token!);
    if (newToken != null) {
      state = state.copyWith(token: newToken);
      return true;
    }
    return false;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ─── Auth Token Provider ─────────────────────────────────────────────────────

/// Derives the current JWT from [authStateProvider] so that every state change
/// automatically propagates — no manual sync needed.
final authTokenProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).token;
});

// ─── Auth State Provider ─────────────────────────────────────────────────────

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(sharedPrefsProvider),
  );
});

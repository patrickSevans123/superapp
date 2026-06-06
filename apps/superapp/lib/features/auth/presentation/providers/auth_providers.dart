import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/jwt_utils.dart';
import '../../../../core/errors/friendly_error.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/api/auth_api_client.dart';
import '../../data/repository/auth_repository.dart';

// ─── Shared Prefs Provider ───────────────────────────────────────────────────

/// Injected in [main.dart] before [runApp] so that the `has_secure_token`
/// boolean hint is read synchronously — no microtask gap on cold start.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

// ─── Auth Repository Provider ────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(authApiClientProvider),
    ref.read(secureStorageProvider),
    ref.read(sharedPrefsProvider),
  );
});

// ─── API Client ──────────────────────────────────────────────────────────────

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  return AuthApiClient(dio: ref.read(authDioProvider));
});

/// Provider for user ID extracted from auth state (used by other providers).
///
/// Falls back to the `user_id` claim in the JWT when the [UserModel] has
/// not been hydrated yet — this is the common case on cold start, where
/// the token is read from secure storage before any user-data fetch has
/// run (see [AuthNotifier.loadToken]).
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.user?.id ?? JwtUtils.userId(auth.token);
});

// ─── Core Auth API wiring ────────────────────────────────────────────────────

/// Adapter that lets the core auth notifier call into the feature's
/// `AuthRepository.tryRefresh` without `core/` importing `features/auth`.
class RepositoryAuthApi implements CoreAuthApi {
  final AuthRepository _repo;
  RepositoryAuthApi(this._repo);

  @override
  Future<String?> refresh(String token) => _repo.tryRefresh(token);
}

/// Factory for the [CoreAuthNotifier] that the app installs in
/// `ProviderScope.overrides` (see `main.dart`). Wires the secure-storage
/// handle and a [RepositoryAuthApi] adapter into the notifier.
CoreAuthNotifier createCoreAuthNotifier(Ref ref) {
  return CoreAuthNotifier(
    storage: ref.watch(secureStorageProvider),
    api: RepositoryAuthApi(ref.watch(authRepositoryProvider)),
    initial: const CoreAuthState(),
  );
}

// ─── Auth State (UI-only extensions) ─────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;
  final UserModel? user;
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
    UserModel? user,
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

// ─── Auth Notifier (UI wrapper) ──────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref, SharedPreferences prefs)
      : super(_loadInitialUiState(prefs));

  static AuthState _loadInitialUiState(SharedPreferences prefs) {
    final hasHint = prefs.getBool(kHasSecureTokenKey) ?? false;
    if (hasHint) {
      // Mark as logged-in optimistically; `loadToken()` will downgrade
      // us if the token turns out to be missing or expired.
      return const AuthState(isLoggedIn: true);
    }
    return const AuthState();
  }

  /// Reads the JWT from secure storage via the core notifier and updates
  /// [state]. Called once from `main.dart` after `runApp` so cold-start
  /// can pick up the token without blocking the UI.
  Future<void> loadToken() async {
    if (!state.isLoggedIn) {
      authRefreshListenable.value = false;
      return;
    }
    final coreNot = _ref.read(coreAuthNotifierProvider.notifier);
    final session = await coreNot.hydrate();
    if (session == null) {
      // The hint was wrong — token was never persisted or already expired.
      state = const AuthState();
      authRefreshListenable.value = false;
      return;
    }
    state = state.copyWith(token: session.token);
    authRefreshListenable.value = true;
  }

  /// Schedules a logout at the JWT's `exp` time, if it expires within
  /// the next 5 minutes. Returns the [Timer] (or `null` if no scheduled
  /// timer is needed) so the caller can cancel it.
  Timer? scheduleExpiryLogout() {
    final token = state.token;
    if (token == null) return null;
    final exp = JwtUtils.expiry(token);
    if (exp == null) return null;
    final now = DateTime.now().toUtc();
    final delta = exp.difference(now);
    if (delta.isNegative) {
      // Already expired — kick off logout immediately.
      logout();
      return null;
    }
    if (delta < const Duration(minutes: 5)) {
      return Timer(delta, () => logout());
    }
    return null;
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
      // Await so the core notifier's token state is updated BEFORE
      // authRefreshListenable flips the router to the post-login view.
      // Without await the AuthInterceptor would send requests without
      // a JWT, causing 401s on every protected endpoint.
      await _ref.read(coreAuthNotifierProvider.notifier).setSession(
            CoreAuthSession(token: result.token),
          );
      authRefreshListenable.value = true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
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
      await _ref.read(coreAuthNotifierProvider.notifier).setSession(
            CoreAuthSession(token: result.token),
          );
      authRefreshListenable.value = true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
    }
  }

  Future<void> logout() async {
    await _ref.read(coreAuthNotifierProvider.notifier).clearSession();
    state = const AuthState();
    authRefreshListenable.value = false;
  }

  /// Attempts a token refresh. Delegates to the core notifier, which
  /// memoises concurrent callers onto a single /auth/refresh round-trip.
  Future<bool> tryRefresh() async {
    final success = await _ref.read(coreAuthNotifierProvider.notifier).tryRefresh();
    if (success) {
      final newToken = _ref.read(coreAuthNotifierProvider).token;
      state = state.copyWith(token: newToken);
    }
    return success;
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
    ref,
    ref.read(sharedPrefsProvider),
  );
});

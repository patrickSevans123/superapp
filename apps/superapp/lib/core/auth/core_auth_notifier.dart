import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_models/shared_models.dart';

import 'jwt_utils.dart';

/// Repository-like dependency the core notifier needs to perform a refresh.
/// The features layer wires the real `AuthRepository` in via
/// [_RepositoryAuthApi] in `auth_providers.dart`.
abstract class CoreAuthApi {
  Future<String?> refresh(String token);
}

/// Minimal signature for the persistable user bundle. Defined in core to keep
/// the notifier free of `features/auth` imports.
class CoreAuthSession {
  final String token;
  final UserModel? user;
  const CoreAuthSession({required this.token, this.user});
}

/// Shared keys for secure storage and the SharedPreferences boolean hint.
const String kAuthTokenKey = 'auth_token';
const String kHasSecureTokenKey = 'has_secure_token';

/// A [Listenable] that flips every time auth state changes.
///
/// GoRouter's `redirect` callback is synchronous and runs outside of
/// Riverpod, so we mirror the auth flip on a [ValueNotifier] and pass
/// that to `refreshListenable`. The core auth notifier mutates this
/// notifier on every login/logout, so callers don't have to remember.
final ValueNotifier<bool> authRefreshListenable = ValueNotifier<bool>(false);

/// Provider for the secure-storage handle. Overridden in tests if needed.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
});

/// The core auth notifier. Owns the JWT, the user, and the refresh / logout
/// pipeline. Lives in `core/` so that infrastructure code (e.g. the Dio
/// [AuthInterceptor]) can call `tryRefresh` and `logout` without crossing
/// into `features/`.
class CoreAuthNotifier extends StateNotifier<CoreAuthState> {
  final FlutterSecureStorage _storage;
  final CoreAuthApi _api;

  /// Memoised refresh future so concurrent 401s share one /auth/refresh
  /// call. Nulled out when the in-flight call completes.
  Completer<String?>? _refreshCompleter;

  /// Optional callback fired after every successful login so the features
  /// notifier can update its own UI state (loading / error / user).
  void Function(CoreAuthSession session)? onSessionSet;
  void Function()? onSessionCleared;

  CoreAuthNotifier({
    required FlutterSecureStorage storage,
    required CoreAuthApi api,
    required CoreAuthState initial,
  })  : _storage = storage,
        _api = api,
        super(initial);

  /// Reads the JWT from secure storage and updates [state]. Returns the
  /// loaded session (or null if there is no valid token).
  Future<CoreAuthSession?> hydrate() async {
    final token = await _storage.read(key: kAuthTokenKey);
    if (token == null) {
      state = const CoreAuthState();
      return null;
    }
    if (JwtUtils.isExpired(token)) {
      await _storage.delete(key: kAuthTokenKey);
      state = const CoreAuthState();
      return null;
    }
    state = CoreAuthState(isLoggedIn: true, token: token);
    return CoreAuthSession(token: token);
  }

  /// Persist a new session (login or refresh). Updates state and notifies
  /// the features notifier via [onSessionSet].
  Future<void> setSession(CoreAuthSession session) async {
    await _storage.write(key: kAuthTokenKey, value: session.token);
    state = CoreAuthState(isLoggedIn: true, token: session.token);
    authRefreshListenable.value = true;
    onSessionSet?.call(session);
  }

  /// Clear the persisted session and reset state.
  Future<void> clearSession() async {
    await _storage.delete(key: kAuthTokenKey);
    state = const CoreAuthState();
    authRefreshListenable.value = false;
    onSessionCleared?.call();
  }

  /// Attempts a token refresh. If multiple 401s come in concurrently, the
  /// second-and-later callers `await` the same in-flight Future instead
  /// of triggering another /auth/refresh round-trip.
  Future<bool> tryRefresh() async {
    final token = state.token;
    if (token == null) return false;

    final existing = _refreshCompleter;
    if (existing != null) {
      final result = await existing.future;
      return result != null;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    try {
      final newToken = await _api.refresh(token);
      if (newToken == null || JwtUtils.isExpired(newToken)) {
        completer.complete(null);
        return false;
      }
      await _storage.write(key: kAuthTokenKey, value: newToken);
      state = CoreAuthState(isLoggedIn: true, token: newToken);
      authRefreshListenable.value = true;
      onSessionSet?.call(CoreAuthSession(token: newToken));
      completer.complete(newToken);
      return true;
    } catch (_) {
      completer.complete(null);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}

/// Minimal auth state shared between `core/` and `features/auth/`.
class CoreAuthState {
  final bool isLoggedIn;
  final String? token;

  const CoreAuthState({this.isLoggedIn = false, this.token});

  CoreAuthState copyWith({bool? isLoggedIn, String? token}) => CoreAuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        token: token ?? this.token,
      );
}

/// Provider for the [CoreAuthNotifier]. The default throws because the
/// notifier needs an authenticated [CoreAuthApi] implementation that
/// only the features layer knows about. The features layer overrides
/// this at the `ProviderScope` level using the
/// [createCoreAuthNotifier] factory function.
final coreAuthNotifierProvider =
    StateNotifierProvider<CoreAuthNotifier, CoreAuthState>((ref) {
  throw UnimplementedError(
    'coreAuthNotifierProvider must be overridden in the features layer '
    'via ProviderScope(overrides: [coreAuthNotifierProvider.overrideWith(createCoreAuthNotifier)])',
  );
});

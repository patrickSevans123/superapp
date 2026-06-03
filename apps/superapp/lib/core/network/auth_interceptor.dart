import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';

/// Interceptor that attaches the JWT token to every request and handles 401
/// responses.
///
/// Reuses the configured [Dio] instance for retries so that base URL, timeouts,
/// headers and other interceptors (including this one) are preserved.
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;

  AuthInterceptor(this._ref, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Read from the core notifier's state directly. This is sync and
    // works even if the features `authStateProvider` is not yet
    // initialised.
    final token = _ref.read(coreAuthNotifierProvider).token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final alreadyRetried = err.requestOptions.extra['auth_retry'] == true;
    if (err.response?.statusCode == 401 && !alreadyRetried) {
      // Try to refresh token before giving up. The core notifier
      // memoises concurrent callers, so even if 5 requests 401
      // simultaneously, only ONE /auth/refresh hits the network.
      final coreNot = _ref.read(coreAuthNotifierProvider.notifier);
      final success = await coreNot.tryRefresh();
      if (success) {
        final newToken = _ref.read(coreAuthNotifierProvider).token;
        if (newToken != null) {
          final retryRequest = err.requestOptions;
          retryRequest.extra['auth_retry'] = true;
          retryRequest.headers['Authorization'] = 'Bearer $newToken';
          try {
            final response = await _dio.fetch(retryRequest);
            handler.resolve(response);
            return;
          } catch (_) {
            // fall through to logout
          }
        }
      }
      // Refresh failed — the request really was unauthorised.
      // Clear the session so the UI reacts. The notifier flips
      // `authRefreshListenable` itself.
      await coreNot.clearSession();
    }
    handler.next(err);
  }
}

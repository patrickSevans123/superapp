import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';

/// Interceptor that attaches the JWT token to every request and handles 401
/// responses.
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authTokenProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh token before giving up
      final notifier = _ref.read(authStateProvider.notifier);
      final success = await notifier.tryRefresh();
      if (success) {
        // Retry the original request with the new token
        final newToken = _ref.read(authTokenProvider);
        if (newToken != null) {
          final retryRequest = err.requestOptions;
          retryRequest.headers['Authorization'] = 'Bearer $newToken';
          try {
            final response = await Dio().fetch(retryRequest);
            handler.resolve(response);
            return;
          } catch (_) {
            // fall through to logout
          }
        }
      }
      notifier.logout();
    }
    handler.next(err);
  }
}

import 'package:dio/dio.dart';

/// Converts arbitrary errors into short, user-facing messages.
///
/// The goal is to avoid leaking internal exception text (stack frames,
/// file paths, raw HTTP responses) into UI surfaces. Callers should use
/// the returned string in SnackBars / inline error text.
String friendlyError(Object? e) {
  if (e == null) return 'Something went wrong. Please try again.';

  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Check your network and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the server. Please check your connection.';
      case DioExceptionType.badCertificate:
        return 'A secure connection could not be established.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401) {
          return 'Your session has expired. Please sign in again.';
        }
        if (code == 403) {
          return 'You do not have permission to do that.';
        }
        if (code == 404) {
          return 'The requested resource was not found.';
        }
        if (code == 429) {
          return 'Too many requests. Please wait a moment and try again.';
        }
        if (code >= 500) {
          return 'The server is having trouble. Please try again shortly.';
        }
        return 'The server returned an error ($code).';
      case DioExceptionType.unknown:
        return 'Network error. Please try again.';
    }
  }

  // Generic fallback — keep it short and avoid raw `e.toString()`.
  final s = e.toString();
  if (s.isEmpty) return 'Something went wrong. Please try again.';
  return 'Something went wrong. Please try again.';
}

import 'dart:convert';
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
        return _handleBadResponse(e);
      case DioExceptionType.unknown:
        return 'Network error. Please try again.';
    }
  }

  // Feature-layer exceptions (e.g. TradeApiException, ScholarshipApiException)
  // store a message and optional statusCode. Extract via toString() pattern
  // so core/ doesn't need to import feature-layer types.
  final msg = _extractMessageFromToString(e);
  if (msg != null) return msg;

  // Generic fallback — keep it short and avoid raw `e.toString()`.
  return 'Something went wrong. Please try again.';
}

/// Extracts a user-friendly message from a bad HTTP response.
///
/// Prefers the server's `error` or `message` field (which are specific,
/// e.g. "email already registered") and falls back to a status-code-
/// based message.
String _handleBadResponse(DioException e) {
  final code = e.response?.statusCode ?? 0;

  // Try to extract the server's error message from the response body.
  final serverMsg = _extractServerMessage(e.response?.data);
  if (serverMsg != null) return serverMsg;

  // Status-code-based fallback.
  if (code == 401) {
    return 'Your session has expired. Please sign in again.';
  }
  if (code == 403) {
    return 'You do not have permission to do that.';
  }
  if (code == 404) {
    return 'The requested resource was not found.';
  }
  if (code == 409) {
    return 'This email is already registered. Try signing in instead.';
  }
  if (code == 429) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (code >= 500) {
    return 'The server is having trouble. Please try again shortly.';
  }
  return 'The server returned an error ($code).';
}

/// Attempts to read an `error` or `message` string from [data].
String? _extractServerMessage(dynamic data) {
  if (data == null) return null;
  try {
    Map<String, dynamic> map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is String) {
      map = jsonDecode(data) as Map<String, dynamic>;
    } else {
      return null;
    }
    // Prefer "error", then "message", then "detail".
    final msg = map['error'] ?? map['message'] ?? map['detail'];
    if (msg is String && msg.isNotEmpty) return msg;
  } catch (_) {
    // Ignore parse errors — fall through to status-code fallback.
  }
  return null;
}

/// Handles feature-layer exceptions like `TradeApiException` or
/// `ScholarshipApiException` whose toString() produces
/// `TradeApiException(503): message` or `ScholarshipApiException(503): message`.
///
/// Extracts the status code for status-based messages, or returns the
/// embedded message directly if it's user-friendly.
String? _extractMessageFromToString(Object e) {
  final s = e.toString();

  // Match pattern: SomeApiException(StatusCode): message
  final match = RegExp(r'\w+Exception\((\d+)\):\s*(.+)').firstMatch(s);
  if (match != null) {
    final code = int.tryParse(match.group(1) ?? '') ?? 0;
    final body = match.group(2)?.trim() ?? '';

    // Try to parse the body as JSON in case it's an error response string.
    final serverMsg = _extractServerMessage(body);
    if (serverMsg != null) return serverMsg;

    // Status-code-based fallback (same as _handleBadResponse).
    if (code == 401) return 'Your session has expired. Please sign in again.';
    if (code == 403) return 'You do not have permission to do that.';
    if (code == 404) return 'The requested resource was not found.';
    if (code == 429) return 'Too many requests. Please wait a moment and try again.';
    if (code >= 500) return 'The server is having trouble. Please try again shortly.';
    if (body.isNotEmpty) return body;
    return 'The server returned an error ($code).';
  }

  // No pattern match — not a known feature exception.
  return null;
}

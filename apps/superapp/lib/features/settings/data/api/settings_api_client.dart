import 'package:dio/dio.dart';

/// Exception thrown by the Settings API client.
class SettingsApiException implements Exception {
  final String message;
  final int? statusCode;

  const SettingsApiException(this.message, {this.statusCode});

  @override
  String toString() => 'SettingsApiException($statusCode): $message';
}

/// API client for the settings backend.
///
/// Communicates with the Go REST API that returns snake_case JSON objects.
///
/// Callers should inject the shared auth-aware [Dio] via
/// `ref.watch(authDioProvider)` so that JWT tokens and 401 handling are
/// applied consistently.
class SettingsApiClient {
  final Dio _dio;

  SettingsApiClient({required Dio dio}) : _dio = dio;

  /// Fetches the settings for the given [userId].
  Future<Map<String, dynamic>> getSettings(String userId) async {
    try {
      final response = await _dio.get(
        '/settings',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw SettingsApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw SettingsApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Updates the settings for the given [userId].
  Future<Map<String, dynamic>> updateSettings(
    String userId, {
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final body = <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (preferences != null) 'preferences': preferences,
      };

      final response = await _dio.patch(
        '/settings',
        queryParameters: {'user_id': userId},
        data: body,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw SettingsApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw SettingsApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

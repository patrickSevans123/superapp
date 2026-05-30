import 'package:dio/dio.dart';
import 'package:shared_models/shared_models.dart';

/// Exception thrown by the Profile API client.
class ProfileApiException implements Exception {
  final String message;
  final int? statusCode;

  const ProfileApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ProfileApiException($statusCode): $message';
}

/// API client for the profile backend.
///
/// Communicates with the Go REST API that returns snake_case JSON objects.
class ProfileApiClient {
  final Dio _dio;

  ProfileApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'http://100.110.59.78:8080/api/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ));

  /// Fetches the profile for the given [userId].
  Future<UserModel> getProfile(String userId) async {
    try {
      final response = await _dio.get(
        '/profile',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw ProfileApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return UserModel.fromJson(dataJson);
    } on DioException catch (e) {
      throw ProfileApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Updates the profile for the given [userId].
  Future<UserModel> updateProfile(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      final response = await _dio.patch(
        '/profile',
        queryParameters: {'user_id': userId},
        data: body,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw ProfileApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return UserModel.fromJson(dataJson);
    } on DioException catch (e) {
      throw ProfileApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

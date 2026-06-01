import 'package:dio/dio.dart';

class AuthApiClient {
  final Dio _dio;

  /// Accepts a [Dio] instance (typically from [authDioProvider])
  /// instead of creating its own — avoids duplicated config.
  AuthApiClient({required Dio dio}) : _dio = dio;

  Future<Map<String, dynamic>> register(
      String email, String password, String displayName) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refresh(String token) async {
    final response = await _dio.post('/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout(String token) async {
    await _dio.post('/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
  }
}

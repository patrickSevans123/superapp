import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthApiClient {
  final Dio _dio;

  AuthApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl:
                  dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ));

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
}

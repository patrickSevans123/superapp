import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';

/// Shared auth-aware [Dio] provider for all API clients.
///
/// All feature-level Dio providers should reference this one so that every
/// outgoing request includes the JWT token and 401 responses trigger a logout.
final authDioProvider = Provider<Dio>((ref) {
  // Configured at build time: flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
  // In release builds, pass --dart-define=API_BASE_URL=https://your-prod-host/api/v1
  // The localhost default is for development only.
  const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(ref, dio));
  return dio;
});

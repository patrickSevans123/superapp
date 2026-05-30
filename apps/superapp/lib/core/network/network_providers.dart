import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';

/// Shared auth-aware [Dio] provider for all API clients.
///
/// All feature-level Dio providers should reference this one so that every
/// outgoing request includes the JWT token and 401 responses trigger a logout.
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://100.110.59.78:8080/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

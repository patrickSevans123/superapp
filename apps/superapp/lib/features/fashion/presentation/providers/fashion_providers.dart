import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api.dart';
import '../../data/repository/repository.dart';

/// Base Dio provider for API calls.
/// Replace baseUrl with the actual backend URL via environment config.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://localhost:8080/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Provides the [FashionApiClient] singleton.
final fashionApiClientProvider = Provider<FashionApiClient>((ref) {
  return FashionApiClient(ref.read(dioProvider));
});

/// Provides the [FashionRepository] singleton.
final fashionRepositoryProvider = Provider<FashionRepository>((ref) {
  return FashionRepository(ref.read(fashionApiClientProvider));
});

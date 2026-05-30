import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/profile_api_client.dart';
import '../../data/repository/profile_repository.dart';

/// Base Dio provider for the profile feature.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://100.110.59.78:8080/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Provides the [ProfileApiClient] singleton.
final profileApiClientProvider = Provider<ProfileApiClient>((ref) {
  return ProfileApiClient(dio: ref.read(dioProvider));
});

/// Provides the [ProfileRepository] singleton.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(profileApiClientProvider));
});

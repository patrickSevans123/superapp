import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/api/profile_api_client.dart';
import '../../data/repository/profile_repository.dart';

/// Provides the [ProfileApiClient] singleton using the shared auth-aware Dio.
final profileApiClientProvider = Provider<ProfileApiClient>((ref) {
  return ProfileApiClient(dio: ref.read(authDioProvider));
});

/// Provides the [ProfileRepository] singleton.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(profileApiClientProvider));
});

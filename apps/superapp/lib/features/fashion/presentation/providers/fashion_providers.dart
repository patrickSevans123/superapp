import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/api/api.dart';
import '../../data/repository/repository.dart';

/// Provides the [FashionApiClient] singleton using the shared auth-aware Dio.
final fashionApiClientProvider = Provider<FashionApiClient>((ref) {
  return FashionApiClient(ref.read(authDioProvider));
});

/// Provides the [FashionRepository] singleton.
final fashionRepositoryProvider = Provider<FashionRepository>((ref) {
  return FashionRepository(ref.read(fashionApiClientProvider));
});

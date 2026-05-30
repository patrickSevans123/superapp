import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/api/api.dart';
import '../../data/repository/repository.dart';

/// Provides the [TradeApiClient] singleton using the shared auth-aware Dio.
final tradeApiClientProvider = Provider<TradeApiClient>((ref) {
  return TradeApiClient(dio: ref.read(authDioProvider));
});

/// Provides the [TradeRepository] singleton.
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository(ref.read(tradeApiClientProvider));
});

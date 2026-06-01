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

/// Per-source news freshness, polled every 60s while at least one consumer
/// is listening. Powers the data-stale banner on the trade dashboard.
final newsStatusProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.getNewsStatus();
});

/// Cross-system scraper health (news + MSCI + trading plans). Same
/// 60s polling cadence as [newsStatusProvider].
final scrapersHealthProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(tradeRepositoryProvider);
  return repo.getScrapersHealth();
});

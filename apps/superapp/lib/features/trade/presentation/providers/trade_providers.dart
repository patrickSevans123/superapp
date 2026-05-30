import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api.dart';
import '../../data/repository/repository.dart';

/// Base Dio provider for the trade feature.
/// Uses the self-trade Go backend directly.
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: 'http://100.110.59.78:8080/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Provides the [TradeApiClient] singleton.
final tradeApiClientProvider = Provider<TradeApiClient>((ref) {
  return TradeApiClient(dio: ref.read(dioProvider));
});

/// Provides the [TradeRepository] singleton.
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository(ref.read(tradeApiClientProvider));
});

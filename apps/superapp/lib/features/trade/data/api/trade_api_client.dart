import 'package:dio/dio.dart';

import '../models/app_event.dart';
import '../models/market_quote.dart';
import '../models/news_item.dart';
import '../models/plans_summary.dart';
import '../models/trading_plan.dart';

/// Exception thrown by the Trade API client.
class TradeApiException implements Exception {
  final String message;
  final int? statusCode;

  const TradeApiException(this.message, {this.statusCode});

  @override
  String toString() => 'TradeApiException($statusCode): $message';
}

/// API client for the trade backend.
///
/// Communicates with the Go REST API that returns snake_case JSON objects.
class TradeApiClient {
  final Dio _dio;

  TradeApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'http://100.110.59.78:8080/api/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ));

  // ─── Quotes ────────────────────────────────────────────────────────

  /// Fetches a single market quote for the given [symbol].
  Future<MarketQuote> getQuote(String symbol) async {
    try {
      final response = await _dio.get('/quotes/$symbol');

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return MarketQuote.fromJson(dataJson);
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches market quotes for the given list of [symbols].
  Future<List<MarketQuote>> getQuotes(List<String> symbols) async {
    try {
      final response = await _dio.get(
        '/quotes',
        queryParameters: {'symbols': symbols.join(',')},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map((e) => MarketQuote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Trading Plans ─────────────────────────────────────────────────

  /// Fetches trading plans, optionally filtered by [status].
  Future<List<TradingPlan>> getPlans({String? status}) async {
    try {
      final queryParams = <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
      };

      final response = await _dio.get(
        '/plans',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map(
                  (e) => TradingPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches the trading plans summary (totals, win rate, etc.).
  Future<PlansSummary> getPlansSummary() async {
    try {
      final response = await _dio.get('/plans/summary');

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return PlansSummary.fromJson(dataJson);
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── News ──────────────────────────────────────────────────────────

  /// Fetches news items, with optional [source] and [limit].
  Future<List<NewsItem>> getNews({
    String source = 'bloomberg_english',
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'source': source,
        'limit': limit,
      };

      final response = await _dio.get(
        '/news',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Events ────────────────────────────────────────────────────────

  /// Fetches app events (alerts, notifications, etc.).
  Future<List<AppEvent>> getEvents() async {
    try {
      final response = await _dio.get('/events');

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map((e) => AppEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

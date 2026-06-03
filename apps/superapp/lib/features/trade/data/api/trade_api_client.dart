import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/briefing_model.dart';
import '../models/decision_model.dart';
import '../models/models.dart';
import '../models/regime_model.dart';
import '../models/signal_model.dart';

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

  TradeApiClient({required Dio dio}) : _dio = dio;

  // ─── Quotes ────────────────────────────────────────────────────────

  /// Fetches a single market quote for the given [symbol].
  Future<MarketQuote> getQuote(String symbol) async {
    try {
      final response = await _dio.get(
        '/market/quote',
        queryParameters: {'symbol': symbol},
      );

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
        '/market/quotes',
        queryParameters: {'symbols': symbols.join(',')},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final rawList = (json['data'] as List<dynamic>?) ??
          (json['quotes'] as List<dynamic>?) ??
          [];
      final dataList = rawList
          .map((e) => MarketQuote.fromJson(e as Map<String, dynamic>))
          .toList();
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

      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return [];
      }
      final dataRaw = json['data'];
      List<TradingPlan> dataList;
      if (dataRaw is List) {
        dataList = dataRaw
            .map((e) => TradingPlan.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (json['plans'] is List) {
        dataList = (json['plans'] as List)
            .map((e) => TradingPlan.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        dataList = [];
      }
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

      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return PlansSummary.fromJson({});
      }
      final dataRaw = json['data'];
      final dataJson = (dataRaw is Map<String, dynamic>) ? dataRaw : json;
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
  ///
  /// Returns a [NewsResult] that bundles the list with freshness metadata
  /// (age of newest article, total count, last-modified mtime) so the UI
  /// can render the "Updated 9m ago" pill without a second round-trip.
  Future<NewsResult> getNews({
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

      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const NewsResult(items: [], ageSeconds: null, count: 0);
      }

      // The self-trade Go API returns the list under "news" (not "data")
      // and exposes metadata fields at the top level. Be lenient and accept
      // both shapes to stay forward-compatible.
      final rawList = (json['news'] as List<dynamic>?) ??
          (json['data'] as List<dynamic>?) ??
          const [];
      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map(NewsItem.fromJson)
          .toList();

      final count = (json['count'] as num?)?.toInt() ?? items.length;
      final ageSec = (json['age_seconds'] as num?)?.toInt();
      final mtime = json['latest_file_mtime'] != null
          ? DateTime.tryParse(json['latest_file_mtime'].toString())
          : null;

      return NewsResult(
        items: items,
        count: count,
        ageSeconds: ageSec,
        ageLabel: json['age']?.toString(),
        latestFileMtime: mtime,
        latestFileSize: (json['latest_file_size_bytes'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches per-source freshness for every news scraper.
  /// GET /api/v1/news/status
  Future<NewsStatus> getNewsStatus() async {
    try {
      final response = await _dio.get('/news/status');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const NewsStatus(
          allOk: true,
          total: 0,
          healthy: 0,
          stale: 0,
          sources: [],
        );
      }
      return NewsStatus.fromJson(_unwrapDegraded(json));
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches per-scraper health across the whole system
  /// (news + MSCI + trading plans).
  /// GET /api/v1/scrapers/health
  Future<ScraperHealth> getScrapersHealth() async {
    try {
      final response = await _dio.get('/scrapers/health');
      // 503 means at least one source is stale — still a valid payload,
      // so we don't throw, we just unwrap and parse the upstream body.
      if (response.statusCode != null &&
          response.statusCode! >= 400 &&
          response.statusCode != 503) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const ScraperHealth(
          allHealthy: true,
          totalCount: 0,
          healthyCount: 0,
          staleCount: 0,
          sources: [],
        );
      }
      return ScraperHealth.fromJson(_unwrapDegraded(json));
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// The api_gateway wraps failed-upstream responses in a
  /// `{degraded:true, raw:"<json-string>", ...}` envelope. When we see
  /// that shape, decode the inner `raw` string so the typed model sees
  /// the actual payload the upstream sent.
  Map<String, dynamic> _unwrapDegraded(Map<String, dynamic> json) {
    if (json['degraded'] == true && json['raw'] is String) {
      try {
        final inner = jsonDecode(json['raw'] as String);
        if (inner is Map<String, dynamic>) return inner;
      } catch (_) {
        // fall through
      }
    }
    return json;
  }

  // ─── Events ────────────────────────────────────────────────────────

  // ─── Signals ────────────────────────────────────────────────────────

  /// Fetches trading signals for the given asset class (idx | us | crypto).
  Future<List<SignalModel>> getSignals(String asset) async {
    try {
      final response = await _dio.get('/signals/$asset');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) return [];
      final rawList = (json['signals'] as List<dynamic>?) ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(SignalModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Regime ─────────────────────────────────────────────────────────

  /// Fetches the current market regime report.
  Future<RegimeReport> getRegime() async {
    try {
      final response = await _dio.get('/regime');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const RegimeReport(
          globalRegime: Regime.bull,
          perAsset: [],
          allocation: [],
          maxLossTolerancePct: 3.0,
          currentDrawdownPct: 0.0,
        );
      }
      return RegimeReport.fromJson(_unwrapDegraded(json));
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Briefing ───────────────────────────────────────────────────────

  /// Fetches today's morning briefing.
  Future<BriefingModel> getBriefing() async {
    try {
      final response = await _dio.get('/briefing/today');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const BriefingModel(date: '', body: '', sizeBytes: 0);
      }
      return BriefingModel.fromJson(json);
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

      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return [];
      }
      final dataRaw = json['data'];
      List<AppEvent> dataList;
      if (dataRaw is List) {
        dataList = dataRaw
            .map((e) => AppEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (json['events'] is List) {
        dataList = (json['events'] as List)
            .map((e) => AppEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        dataList = [];
      }
      return dataList;
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Decisions ──────────────────────────────────────────────────────

  /// Fetches trading decisions from the AI decision memory.
  Future<({List<DecisionModel> decisions, LearningStats stats})> getDecisions({
    String? ticker,
    int limit = 20,
    bool withReflections = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'with_reflections': withReflections.toString(),
      };
      if (ticker != null && ticker.isNotEmpty) {
        queryParams['ticker'] = ticker;
      }

      final response = await _dio.get('/decisions', queryParameters: queryParams);
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return (decisions: <DecisionModel>[], stats: const LearningStats(
          totalDecisions: 0, totalWithOutcomes: 0, winRate: 0, avgReturn: 0, avgAlpha: 0,
        ));
      }
      final rawList = (json['decisions'] as List<dynamic>?) ?? [];
      final decisions = rawList
          .whereType<Map<String, dynamic>>()
          .map(DecisionModel.fromJson)
          .toList();
      final statsJson = json['learningStats'] as Map<String, dynamic>? ?? {};
      final stats = LearningStats.fromJson(statsJson);
      return (decisions: decisions, stats: stats);
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── P2: Strategy Performance ───────────────────────────────────────

  /// Fetches all strategy backtest performance results.
  Future<List<StrategyPerformance>> getStrategyPerformance() async {
    try {
      final response = await _dio.get('/strategy-performance');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) return [];
      final rawList = (json['strategies'] as List<dynamic>?) ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(StrategyPerformance.fromJson)
          .toList();
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── P2: Factor Scores ─────────────────────────────────────────────

  /// Fetches composite factor scores for IDX stocks.
  Future<FactorResponse> getFactors() async {
    try {
      final response = await _dio.get('/factors');
      if (response.statusCode != 200 || response.data == null) {
        throw TradeApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        return const FactorResponse(
          factors: [], count: 0, factorNames: [], methodology: '',
        );
      }
      return FactorResponse.fromJson(json);
    } on DioException catch (e) {
      throw TradeApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

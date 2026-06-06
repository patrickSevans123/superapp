import 'package:dio/dio.dart';

import '../models/daily_report.dart';
import '../models/research_report.dart';
import '../models/research_report_source.dart';

/// Exception thrown by the Reports API client.
class ReportsApiException implements Exception {
  final String message;
  final int? statusCode;

  const ReportsApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ReportsApiException($statusCode): $message';
}

/// API client for the new Reports backend endpoints.
///
/// * `GET /api/v1/reports` — daily trading reports
/// * `GET /api/v1/reports?date=YYYY-MM-DD` — single report by date
/// * `GET /api/v1/research-reports?source=&limit=` — broker research list
/// * `GET /api/v1/research-reports/:id` — single research report
///
/// All requests go through the shared auth-aware Dio (which attaches the
/// JWT and triggers logout on 401).  JSON shapes are accepted leniently:
/// the wrapper may put the list under `data`, `reports`,
/// `research_reports`, or return a bare array — we try them all.
class ReportsApiClient {
  final Dio _dio;

  ReportsApiClient({required Dio dio}) : _dio = dio;

  // ─── Daily reports ─────────────────────────────────────────────────────

  /// Fetches daily reports, newest first.  When [date] is supplied the
  /// backend returns the single report for that calendar day (or 404
  /// → we surface as an empty list).
  Future<List<DailyReport>> listDailyReports({
    DateTime? date,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (date != null) 'date': _isoDate(date),
        'limit': limit,
      };

      final response = await _dio.get(
        '/reports',
        queryParameters: queryParams,
      );

      if (response.statusCode == 404) {
        return const [];
      }
      if (response.statusCode != 200 || response.data == null) {
        throw ReportsApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final rawList = _extractList(response.data);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(DailyReport.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ReportsApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Convenience: returns the most recent daily report or `null` if none.
  Future<DailyReport?> getLatestDailyReport() async {
    final list = await listDailyReports(limit: 1);
    return list.isEmpty ? null : list.first;
  }

  // ─── Research reports ──────────────────────────────────────────────────

  /// Lists research reports from any source, optionally filtered.
  ///
  /// Graceful degradation: 404 and 5xx are treated as "no data" rather
  /// than surfaced as an error. The Flutter Research Reports screen
  /// has its own empty-state widget, so this keeps it clean when the
  /// upstream service is degraded. The underlying [ReportsApiException]
  /// is reserved for *real* errors (network down, invalid JSON, etc).
  Future<List<ResearchReport>> listResearchReports({
    ResearchReportSource? source,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (source != null) 'source': source.apiValue,
        'limit': limit,
      };

      final response = await _dio.get(
        '/research-reports',
        queryParameters: queryParams,
      );

      // 404 / 5xx / empty body → empty list. The api-gateway returns
      // 200 + {research_reports: []} when the source has no data, but
      // we keep these as a safety net for any other 4xx that bubbles
      // up (e.g. the server is mid-deploy and resets the connection).
      if (response.statusCode == 404 ||
          response.statusCode == 503 ||
          (response.statusCode != null && response.statusCode! >= 500)) {
        return const [];
      }
      if (response.statusCode != 200 || response.data == null) {
        throw ReportsApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final rawList = _extractList(response.data);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ResearchReport.fromJson)
          .toList();
    } on DioException catch (e) {
      // Network-level failures: still return empty rather than
      // surfacing an ugly "DioException [...] has been thrown because
      // the response has a status code of 404" error widget.
      final code = e.response?.statusCode;
      if (code == 404 || (code != null && code >= 500)) {
        return const [];
      }
      throw ReportsApiException(
        e.message ?? 'Network error',
        statusCode: code,
      );
    }
  }

  /// Fetches a single research report by its [id].
  ///
  /// 404 → throws [ReportsApiException] with statusCode 404 (the
  /// research_report_detail_screen handles this with a clean "not
  /// found" UI). 5xx → throws generic exception. The screen never sees
  /// a raw DioException with a giant stack-trace message.
  Future<ResearchReport> getResearchReport(String id) async {
    try {
      final response = await _dio.get('/research-reports/$id');
      if (response.statusCode == 404) {
        throw ReportsApiException(
          'Research report not found',
          statusCode: 404,
        );
      }
      if (response.statusCode != 200 || response.data == null) {
        throw ReportsApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final json = response.data as Map<String, dynamic>;
      // Support both `{ data: { id, ... } }` and bare `{ id, ... }`.
      Map<String, dynamic> inner;
      if (json['data'] is Map<String, dynamic>) {
        inner = json['data'] as Map<String, dynamic>;
      } else {
        inner = json;
      }
      // Defensive: if the inner object is empty / has no id, treat as
      // a 404 (e.g. the gateway stub returned {reflection: null}).
      if (inner.isEmpty || inner['id'] == null || (inner['id'] is String && (inner['id'] as String).isEmpty)) {
        throw ReportsApiException(
          'Research report not found',
          statusCode: 404,
        );
      }
      return ResearchReport.fromJson(inner);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        throw ReportsApiException(
          'Research report not found',
          statusCode: 404,
        );
      }
      throw ReportsApiException(
        e.message ?? 'Network error',
        statusCode: code,
      );
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  /// Tolerates a bare `[...]` response, `{ "data": [...] }`,
  /// `{ "reports": [...] }`, and `{ "research_reports": [...] }`.
  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      for (final key in const ['data', 'reports', 'research_reports']) {
        final v = body[key];
        if (v is List) return v;
      }
    }
    return const [];
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

// ─── LPDP API Client ─────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

import '../models/lpdp_models.dart';

/// Exception thrown by the LPDP API client.
class LpdpApiException implements Exception {
  final String message;
  final int? statusCode;

  const LpdpApiException(this.message, {this.statusCode});

  @override
  String toString() => 'LpdpApiException($statusCode): $message';
}

/// API client for LPDP (Beasiswa Unggulan) endpoints.
///
/// Communicates with the beasiswa scraper MCP server via the auth Dio instance.
/// Base URL is configurable via environment (defaults to localhost:8080/api/v1).
class LpdpApiClient {
  final Dio _dio;

  LpdpApiClient(this._dio);

  /// Fetches all LPDP partner universities.
  Future<List<LpdpUniversity>> getUniversities() async {
    try {
      final response = await _dio.get('/lpdp/universities');

      if (response.statusCode != 200 || response.data == null) {
        throw LpdpApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?) ??
          (json['universities'] as List<dynamic>?) ??
          (response.data as List<dynamic>);

      return dataList
          .map((e) => LpdpUniversity.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw LpdpApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches programs filtered by a strategic field ([bidang]).
  Future<List<LpdpProgram>> getPrograms(String bidang) async {
    try {
      final response = await _dio.get(
        '/lpdp/programs',
        queryParameters: {'bidang': bidang},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw LpdpApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?) ??
          (json['programs'] as List<dynamic>?) ??
          (response.data as List<dynamic>);

      return dataList
          .map((e) => LpdpProgram.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw LpdpApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches a single university (with its programs) by name.
  Future<LpdpUniversity> getUniversityDetail(String name) async {
    try {
      final encoded = Uri.encodeComponent(name);
      final response = await _dio.get('/lpdp/universities/$encoded');

      if (response.statusCode != 200 || response.data == null) {
        throw LpdpApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;

      return LpdpUniversity.fromJson(dataJson);
    } on DioException catch (e) {
      throw LpdpApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches LPDP statistics (university/program counts, etc.).
  Future<LpdpStats> getStats() async {
    try {
      final response = await _dio.get('/lpdp/stats');

      if (response.statusCode != 200 || response.data == null) {
        throw LpdpApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataJson = (json['data'] as Map<String, dynamic>?) ?? json;

      return LpdpStats.fromJson(dataJson);
    } on DioException catch (e) {
      throw LpdpApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Searches LPDP programs by [query].
  Future<List<LpdpProgram>> search(String query) async {
    try {
      final response = await _dio.get(
        '/lpdp/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode != 200 || response.data == null) {
        throw LpdpApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?) ??
          (json['results'] as List<dynamic>?) ??
          (response.data as List<dynamic>);

      return dataList
          .map((e) => LpdpProgram.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw LpdpApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

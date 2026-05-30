import 'package:dio/dio.dart';

import '../models/scholarship_model.dart';

/// Exception thrown by the Scholarship API client.
class ScholarshipApiException implements Exception {
  final String message;
  final int? statusCode;

  const ScholarshipApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ScholarshipApiException($statusCode): $message';
}

/// Wrapper for the paginated list response from the scholarship API.
class ScholarshipListResponse {
  final List<ScholarshipModel> data;
  final int total;
  final int page;
  final int limit;

  const ScholarshipListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory ScholarshipListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>?)
            ?.map((e) =>
                ScholarshipModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ScholarshipListResponse(
      data: dataList,
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
        'data': data.map((e) => e.toJson()).toList(),
        'total': total,
        'page': page,
        'limit': limit,
      };
}

/// API client for the scholarship backend.
///
/// Communicates with a REST API that returns snake_case JSON objects.
/// Base URL is configurable — defaults to localhost:8080/api/v1.
class ScholarshipApiClient {
  final Dio _dio;

  ScholarshipApiClient(this._dio);

  /// Fetches a paginated list of scholarships.
  ///
  /// [q] — free-text search query.
  /// [level] — filter by education level.
  /// [country] — filter by destination country.
  /// [fundingType] — filter by funding type (e.g. "full", "partial").
  /// [page] — page number (1-indexed).
  /// [limit] — results per page.
  Future<ScholarshipListResponse> listScholarships({
    String? q,
    String? level,
    String? country,
    String? fundingType,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (q != null && q.isNotEmpty) 'q': q,
        if (level != null && level.isNotEmpty) 'level': level,
        if (country != null && country.isNotEmpty) 'country': country,
        if (fundingType != null && fundingType.isNotEmpty)
          'funding_type': fundingType,
        'page': page,
        'limit': limit,
      };

      final response = await _dio.get(
        '/scholarships',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw ScholarshipApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return ScholarshipListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ScholarshipApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches a single scholarship by its [id].
  Future<ScholarshipModel> getScholarship(String id) async {
    try {
      final response = await _dio.get('/scholarships/$id');

      if (response.statusCode != 200 || response.data == null) {
        throw ScholarshipApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Support both wrapper { "data": { ... } } and direct object responses
      final json = response.data as Map<String, dynamic>;
      final scholarshipJson =
          (json['data'] as Map<String, dynamic>?) ?? json;

      return ScholarshipModel.fromJson(scholarshipJson);
    } on DioException catch (e) {
      throw ScholarshipApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

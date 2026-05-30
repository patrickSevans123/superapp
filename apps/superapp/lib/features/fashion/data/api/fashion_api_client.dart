import 'package:dio/dio.dart';

import '../models/clothing_item_model.dart';
import '../models/tryon_result_model.dart';

/// Exception thrown by the Fashion API client.
class FashionApiException implements Exception {
  final String message;
  final int? statusCode;

  const FashionApiException(this.message, {this.statusCode});

  @override
  String toString() => 'FashionApiException($statusCode): $message';
}

/// Wrapper for the paginated wardrobe list response.
class WardrobeListResponse {
  final List<ClothingItemModel> data;
  final int total;
  final int page;
  final int limit;

  const WardrobeListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory WardrobeListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List<dynamic>?)
            ?.map((e) =>
                ClothingItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return WardrobeListResponse(
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

/// API client for the fashion backend.
///
/// Communicates with the Go REST API that returns snake_case JSON objects.
/// Base URL is configured via the injected [Dio] instance.
class FashionApiClient {
  final Dio _dio;

  FashionApiClient(this._dio);

  // ─── Wardrobe CRUD ──────────────────────────────────────────────────

  /// Fetches a paginated list of wardrobe items.
  ///
  /// [page] — page number (1-indexed).
  /// [limit] — results per page.
  /// [category] — filter by category.
  /// [season] — filter by season tag.
  /// [search] — free-text search query.
  Future<WardrobeListResponse> getWardrobe({
    int page = 1,
    int limit = 20,
    String? category,
    String? season,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        if (season != null && season.isNotEmpty) 'season': season,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _dio.get(
        '/wardrobe',
        queryParameters: queryParams,
      );

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return WardrobeListResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Creates a new clothing item.
  Future<ClothingItemModel> createItem(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/wardrobe', data: data);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final itemJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return ClothingItemModel.fromJson(itemJson);
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to create item',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches a single clothing item by [id].
  Future<ClothingItemModel> getItem(String id) async {
    try {
      final response = await _dio.get('/wardrobe/$id');

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final itemJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return ClothingItemModel.fromJson(itemJson);
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Updates a clothing item by [id].
  Future<ClothingItemModel> updateItem(
      String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/wardrobe/$id', data: data);

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final itemJson = (json['data'] as Map<String, dynamic>?) ?? json;
      return ClothingItemModel.fromJson(itemJson);
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to update item',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Deletes a clothing item by [id].
  Future<void> deleteItem(String id) async {
    try {
      final response = await _dio.delete('/wardrobe/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to delete item',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Marks a clothing item as worn (increments times_worn).
  Future<void> markWorn(String id) async {
    try {
      final response = await _dio.post('/wardrobe/$id/worn');

      if (response.statusCode != 200) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to mark item as worn',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Insights ───────────────────────────────────────────────────────

  /// Fetches wardrobe insights including CPW data, category breakdown, etc.
  Future<Map<String, dynamic>> getInsights() async {
    try {
      final response = await _dio.get('/wardrobe/insights');

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      return (json['data'] as Map<String, dynamic>?) ?? json;
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to fetch insights',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── Try-On ─────────────────────────────────────────────────────────

  /// Fetches the virtual try-on history.
  Future<List<TryonResult>> getTryonHistory() async {
    try {
      final response = await _dio.get('/tryon/history');

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map(
                  (e) => TryonResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to fetch try-on history',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Submits a garment and person image for virtual try-on.
  Future<Map<String, dynamic>> submitTryon(
    String garmentImageUrl,
    String personImageUrl,
  ) async {
    try {
      final response = await _dio.post(
        '/tryon',
        data: {
          'garment_image_url': garmentImageUrl,
          'person_image_url': personImageUrl,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      return (json['data'] as Map<String, dynamic>?) ?? json;
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to submit try-on',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ─── OOTD ───────────────────────────────────────────────────────────

  /// Fetches Outfit-of-the-Day logs.
  Future<List<Map<String, dynamic>>> getOOTDLogs() async {
    try {
      final response = await _dio.get('/ootd');

      if (response.statusCode != 200 || response.data == null) {
        throw FashionApiException(
          'Unexpected response: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final json = response.data as Map<String, dynamic>;
      final dataList = (json['data'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      return dataList;
    } on DioException catch (e) {
      throw FashionApiException(
        e.message ?? 'Failed to fetch OOTD logs',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

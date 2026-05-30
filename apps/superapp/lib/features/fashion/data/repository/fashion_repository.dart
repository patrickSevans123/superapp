import '../api/fashion_api_client.dart';
import '../models/clothing_item_model.dart';
import '../models/tryon_result_model.dart';

/// Repository that mediates between the [FashionApiClient] and the rest of
/// the app. Wraps API calls with consistent error handling.
class FashionRepository {
  final FashionApiClient _api;

  FashionRepository(this._api);

  // ─── Wardrobe CRUD ──────────────────────────────────────────────────

  /// Fetches a paginated list of wardrobe items.
  Future<WardrobeListResponse> getWardrobe({
    int page = 1,
    int limit = 20,
    String? category,
    String? season,
    String? search,
  }) async {
    try {
      return await _api.getWardrobe(
        page: page,
        limit: limit,
        category: category,
        season: season,
        search: search,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new clothing item.
  Future<ClothingItemModel> createItem(Map<String, dynamic> data) async {
    try {
      return await _api.createItem(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves a single clothing item by [id].
  Future<ClothingItemModel> getItem(String id) async {
    try {
      return await _api.getItem(id);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates a clothing item by [id].
  Future<ClothingItemModel> updateItem(
      String id, Map<String, dynamic> data) async {
    try {
      return await _api.updateItem(id, data);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a clothing item by [id].
  Future<void> deleteItem(String id) async {
    try {
      await _api.deleteItem(id);
    } catch (e) {
      rethrow;
    }
  }

  /// Marks a clothing item as worn.
  Future<void> markWorn(String id) async {
    try {
      await _api.markWorn(id);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Insights ───────────────────────────────────────────────────────

  /// Fetches wardrobe insights.
  Future<Map<String, dynamic>> getInsights() async {
    try {
      return await _api.getInsights();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Try-On ─────────────────────────────────────────────────────────

  /// Fetches the virtual try-on history.
  Future<List<TryonResult>> getTryonHistory() async {
    try {
      return await _api.getTryonHistory();
    } catch (e) {
      rethrow;
    }
  }

  /// Submits a garment and person image for virtual try-on.
  Future<Map<String, dynamic>> submitTryon(
    String garmentImageUrl,
    String personImageUrl,
  ) async {
    try {
      return await _api.submitTryon(garmentImageUrl, personImageUrl);
    } catch (e) {
      rethrow;
    }
  }

  // ─── OOTD ───────────────────────────────────────────────────────────

  /// Fetches Outfit-of-the-Day logs.
  Future<List<Map<String, dynamic>>> getOOTDLogs() async {
    try {
      return await _api.getOOTDLogs();
    } catch (e) {
      rethrow;
    }
  }
}

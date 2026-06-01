import '../api/scholarship_api_client.dart';
import '../models/scholarship_model.dart';

/// Filter parameters for searching scholarships.
class ScholarshipFilters {
  final String? q;
  final String? level;
  final String? country;
  final String? fundingType;
  final String? sortBy;
  final String? sortOrder;
  final int? deadlineDays;
  final int page;
  final int limit;

  const ScholarshipFilters({
    this.q,
    this.level,
    this.country,
    this.fundingType,
    this.sortBy,
    this.sortOrder,
    this.deadlineDays,
    this.page = 1,
    this.limit = 20,
  });

  ScholarshipFilters copyWith({
    String? q,
    String? level,
    String? country,
    String? fundingType,
    String? sortBy,
    String? sortOrder,
    int? deadlineDays,
    int? page,
    int? limit,
    bool clearQ = false,
    bool clearLevel = false,
    bool clearCountry = false,
    bool clearFundingType = false,
    bool clearSortBy = false,
    bool clearSortOrder = false,
    bool clearDeadlineDays = false,
  }) {
    return ScholarshipFilters(
      q: clearQ ? null : (q ?? this.q),
      level: clearLevel ? null : (level ?? this.level),
      country: clearCountry ? null : (country ?? this.country),
      fundingType:
          clearFundingType ? null : (fundingType ?? this.fundingType),
      sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
      sortOrder: clearSortOrder ? null : (sortOrder ?? this.sortOrder),
      deadlineDays:
          clearDeadlineDays ? null : (deadlineDays ?? this.deadlineDays),
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScholarshipFilters &&
          runtimeType == other.runtimeType &&
          q == other.q &&
          level == other.level &&
          country == other.country &&
          fundingType == other.fundingType &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder &&
          deadlineDays == other.deadlineDays &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode =>
      Object.hash(q, level, country, fundingType, sortBy, sortOrder, deadlineDays, page, limit);
}

/// Repository that mediates between the API client and the rest of the app.
class ScholarshipRepository {
  final ScholarshipApiClient _api;

  ScholarshipRepository(this._api);

  /// Searches scholarships using the given [filters].
  Future<ScholarshipListResponse> searchScholarships(
      ScholarshipFilters filters) async {
    return _api.listScholarships(
      q: filters.q,
      level: filters.level,
      country: filters.country,
      fundingType: filters.fundingType,
      sortBy: filters.sortBy,
      sortOrder: filters.sortOrder,
      deadlineDays: filters.deadlineDays,
      page: filters.page,
      limit: filters.limit,
    );
  }

  /// Retrieves a single scholarship by its [id].
  Future<ScholarshipModel> getById(String id) async {
    return _api.getScholarship(id);
  }

  /// Saves (bookmarks) a scholarship for a user.
  Future<bool> saveScholarship(String id, String userId,
      {String status = 'saved'}) async {
    return _api.saveScholarship(id, userId, status: status);
  }

  /// Removes a saved/bookmarked scholarship.
  Future<bool> unsaveScholarship(String id, String userId) async {
    return _api.unsaveScholarship(id, userId);
  }

  /// Fetches the list of saved scholarship IDs for a user.
  Future<List<String>> getSavedScholarshipIds(String userId) async {
    return _api.getSavedScholarshipIds(userId);
  }

  /// Fetches multiple scholarships in a single batch request.
  Future<List<ScholarshipModel>> getScholarshipsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return _api.getScholarshipsBatch(ids);
  }

  /// Fetches related scholarships for the given [id].
  Future<List<ScholarshipModel>> getRelated(String id, {int limit = 6}) async {
    return _api.getRelatedScholarships(id, limit: limit);
  }

  /// Fetches scholarship statistics.
  Future<Map<String, dynamic>> getStats() async {
    return _api.getScholarshipStats();
  }
}

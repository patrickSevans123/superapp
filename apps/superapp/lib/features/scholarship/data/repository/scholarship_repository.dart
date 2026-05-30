import '../api/scholarship_api_client.dart';
import '../models/scholarship_model.dart';

/// Filter parameters for searching scholarships.
class ScholarshipFilters {
  final String? q;
  final String? level;
  final String? country;
  final String? fundingType;
  final int page;
  final int limit;

  const ScholarshipFilters({
    this.q,
    this.level,
    this.country,
    this.fundingType,
    this.page = 1,
    this.limit = 20,
  });

  ScholarshipFilters copyWith({
    String? q,
    String? level,
    String? country,
    String? fundingType,
    int? page,
    int? limit,
    bool clearQ = false,
    bool clearLevel = false,
    bool clearCountry = false,
    bool clearFundingType = false,
  }) {
    return ScholarshipFilters(
      q: clearQ ? null : (q ?? this.q),
      level: clearLevel ? null : (level ?? this.level),
      country: clearCountry ? null : (country ?? this.country),
      fundingType:
          clearFundingType ? null : (fundingType ?? this.fundingType),
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
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode =>
      Object.hash(q, level, country, fundingType, page, limit);
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
      page: filters.page,
      limit: filters.limit,
    );
  }

  /// Retrieves a single scholarship by its [id].
  Future<ScholarshipModel> getById(String id) async {
    return _api.getScholarship(id);
  }
}

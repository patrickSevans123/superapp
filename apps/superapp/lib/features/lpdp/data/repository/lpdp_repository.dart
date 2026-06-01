// ─── LPDP Repository ─────────────────────────────────────────────────────────

import '../api/lpdp_api_client.dart';
import '../models/lpdp_models.dart';

/// Repository that mediates between the LPDP API client and the rest of the app.
class LpdpRepository {
  final LpdpApiClient _api;

  LpdpRepository(this._api);

  /// Fetches all LPDP partner universities.
  Future<List<LpdpUniversity>> getUniversities() async {
    return _api.getUniversities();
  }

  /// Fetches programs filtered by a strategic field.
  Future<List<LpdpProgram>> getPrograms(String bidang) async {
    return _api.getPrograms(bidang);
  }

  /// Fetches a single university with its programs by name.
  Future<LpdpUniversity> getUniversityDetail(String name) async {
    return _api.getUniversityDetail(name);
  }

  /// Fetches LPDP statistics.
  Future<LpdpStats> getStats() async {
    return _api.getStats();
  }

  /// Searches LPDP programs by query.
  Future<List<LpdpProgram>> search(String query) async {
    return _api.search(query);
  }
}

// ─── Scholarship Riverpod Providers ───────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/scholarship_api_client.dart';
import '../../data/repository/scholarship_repository.dart';
import '../../data/models/scholarship_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/network/network_providers.dart';

// ─── API Client & Repository Providers ────────────────────────────────────

final scholarshipApiClientProvider = Provider<ScholarshipApiClient>((ref) {
  return ScholarshipApiClient(ref.read(authDioProvider));
});

final scholarshipRepositoryProvider = Provider<ScholarshipRepository>((ref) {
  return ScholarshipRepository(ref.read(scholarshipApiClientProvider));
});

// ─── Sort Options ─────────────────────────────────────────────────────────

enum ScholarshipSort {
  updatedAt('Updated', 'updated_at'),
  deadline('Deadline', 'deadline'),
  title('Title', 'title');

  final String label;
  final String apiValue;
  const ScholarshipSort(this.label, this.apiValue);
}

enum ScholarshipSortOrder {
  desc('Newest First', 'DESC'),
  asc('Oldest First', 'ASC');

  final String label;
  final String apiValue;
  const ScholarshipSortOrder(this.label, this.apiValue);
}

// ─── Browse Filter State (UI layer) ───────────────────────────────────────

class BrowseFilters {
  final String search;
  final String level;
  final String country;
  final String funding;
  final ScholarshipSort sortBy;
  final ScholarshipSortOrder sortOrder;
  final int? deadlineDays; // filter: deadline within N days (null = no filter)

  const BrowseFilters({
    this.search = '',
    this.level = 'All',
    this.country = 'All',
    this.funding = 'All',
    this.sortBy = ScholarshipSort.updatedAt,
    this.sortOrder = ScholarshipSortOrder.desc,
    this.deadlineDays,
  });

  BrowseFilters copyWith({
    String? search,
    String? level,
    String? country,
    String? funding,
    ScholarshipSort? sortBy,
    ScholarshipSortOrder? sortOrder,
    int? deadlineDays,
    bool clearDeadlineDays = false,
  }) {
    return BrowseFilters(
      search: search ?? this.search,
      level: level ?? this.level,
      country: country ?? this.country,
      funding: funding ?? this.funding,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      deadlineDays:
          clearDeadlineDays ? null : (deadlineDays ?? this.deadlineDays),
    );
  }

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      level != 'All' ||
      country != 'All' ||
      funding != 'All' ||
      deadlineDays != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowseFilters &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          level == other.level &&
          country == other.country &&
          funding == other.funding &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder &&
          deadlineDays == other.deadlineDays;

  @override
  int get hashCode =>
      Object.hash(search, level, country, funding, sortBy, sortOrder, deadlineDays);
}

// ─── Browse Filters Notifier ─────────────────────────────────────────────

class BrowseFiltersNotifier extends StateNotifier<BrowseFilters> {
  BrowseFiltersNotifier() : super(const BrowseFilters());

  Timer? _debounce;

  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(search: value);
    });
  }

  void setLevel(String value) => state = state.copyWith(level: value);
  void setCountry(String value) => state = state.copyWith(country: value);
  void setFunding(String value) => state = state.copyWith(funding: value);

  void setSortBy(ScholarshipSort sort) =>
      state = state.copyWith(sortBy: sort);
  void setSortOrder(ScholarshipSortOrder order) =>
      state = state.copyWith(sortOrder: order);
  void setDeadlineDays(int? days) =>
      state = state.copyWith(deadlineDays: days, clearDeadlineDays: days == null);

  void clearFilters() => state = const BrowseFilters();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final browseFiltersProvider =
    StateNotifierProvider<BrowseFiltersNotifier, BrowseFilters>((ref) {
  return BrowseFiltersNotifier();
});

// ─── Country Options Helper ──────────────────────────────────────────────

final List<String> _orderedCountries = [
  'All',
  'Amerika Serikat',
  'Australia',
  'Belanda',
  'Indonesia',
  'Inggris',
  'Jepang',
  'Jerman',
  'Korea Selatan',
  'Singapura',
  'Swiss',
  'Tiongkok',
];

final allCountryOptionsProvider = Provider<List<String>>((ref) {
  return _orderedCountries;
});

// ─── Provider: Scholarships List ─────────────────────────────────────────

final scholarshipsProvider =
    FutureProvider.autoDispose<List<ScholarshipModel>>((ref) async {
  final filters = ref.watch(browseFiltersProvider);
  final repo = ref.read(scholarshipRepositoryProvider);

  final result = await repo.searchScholarships(
    ScholarshipFilters(
      q: filters.search.isNotEmpty ? filters.search : null,
      level: filters.level != 'All' ? filters.level : null,
      country: filters.country != 'All' ? filters.country : null,
      fundingType: filters.funding != 'All' ? filters.funding : null,
      sortBy: filters.sortBy.apiValue,
      sortOrder: filters.sortOrder.apiValue,
      deadlineDays: filters.deadlineDays,
      page: 1,
      limit: 100,
    ),
  );

  return result.data;
});

// ─── Provider: Scholarship Detail ────────────────────────────────────────

final scholarshipDetailProvider =
    FutureProvider.autoDispose.family<ScholarshipModel, String>(
        (ref, id) async {
  final repo = ref.read(scholarshipRepositoryProvider);
  return repo.getById(id);
});

// ─── Saved Scholarship IDs (API-backed) ──────────────────────────────────

/// Notifier that manages saved (bookmarked) scholarship IDs via API.
class SavedIdsNotifier extends StateNotifier<Set<String>> {
  final ScholarshipRepository _repo;
  final String _userId;

  SavedIdsNotifier(this._repo, this._userId) : super({});

  /// Load saved IDs from the API. Call once on first access.
  Future<void> load() async {
    try {
      final ids = await _repo.getSavedScholarshipIds(_userId);
      state = ids.toSet();
    } catch (_) {
      // Silent fail — show empty set on error
    }
  }

  /// Toggle save/unsave via API. Returns the new state (true = saved).
  Future<bool> toggle(String id) async {
    if (state.contains(id)) {
      await _repo.unsaveScholarship(id, _userId);
      state = Set.from(state)..remove(id);
      return false;
    } else {
      await _repo.saveScholarship(id, _userId);
      state = Set.from(state)..add(id);
      return true;
    }
  }

  Future<void> save(String id) async {
    await _repo.saveScholarship(id, _userId);
    state = Set.from(state)..add(id);
  }

  Future<void> unsave(String id) async {
    await _repo.unsaveScholarship(id, _userId);
    state = Set.from(state)..remove(id);
  }
}

/// Provider for the set of saved scholarship IDs.
final savedIdsProvider =
    StateNotifierProvider<SavedIdsNotifier, Set<String>>((ref) {
  final repo = ref.read(scholarshipRepositoryProvider);
  final userId = ref.read(currentUserIdProvider) ?? '';
  return SavedIdsNotifier(repo, userId);
});

/// Provider that resolves saved IDs to full [ScholarshipModel] objects.
final savedScholarshipsProvider =
    FutureProvider.autoDispose<List<ScholarshipModel>>((ref) async {
  final ids = ref.watch(savedIdsProvider);
  if (ids.isEmpty) return [];
  final repo = ref.read(scholarshipRepositoryProvider);

  // Use batch endpoint (falls back to individual fetches on error)
  try {
    return await repo.getScholarshipsByIds(ids.toList());
  } catch (_) {
    // Fallback: fetch each individually (capped at 20)
    final results = <ScholarshipModel>[];
    for (final id in ids.take(20)) {
      try {
        results.add(await repo.getById(id));
      } catch (_) {}
    }
    return results;
  }
});

// ─── Provider: Related Scholarships ──────────────────────────────────────

final relatedScholarshipsProvider =
    FutureProvider.autoDispose.family<List<ScholarshipModel>, String>(
        (ref, id) async {
  final repo = ref.read(scholarshipRepositoryProvider);
  return repo.getRelated(id);
});

// ─── Provider: Scholarship Stats ─────────────────────────────────────────

final scholarshipStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.read(scholarshipRepositoryProvider);
  return repo.getStats();
});

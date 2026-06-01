// ─── LPDP Riverpod Providers ─────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/lpdp_api_client.dart';
import '../../data/repository/lpdp_repository.dart';
import '../../data/models/lpdp_models.dart';
import '../../../../core/network/network_providers.dart';

// ─── API Client & Repository Providers ─────────────────────────────────────

final lpdpApiClientProvider = Provider<LpdpApiClient>((ref) {
  return LpdpApiClient(ref.read(authDioProvider));
});

final lpdpRepositoryProvider = Provider<LpdpRepository>((ref) {
  return LpdpRepository(ref.read(lpdpApiClientProvider));
});

// ─── Provider: Universities List ──────────────────────────────────────────

final lpdpUniversitiesProvider =
    FutureProvider.autoDispose<List<LpdpUniversity>>((ref) async {
  final repo = ref.read(lpdpRepositoryProvider);
  return repo.getUniversities();
});

// ─── Provider: Stats ──────────────────────────────────────────────────────

final lpdpStatsProvider =
    FutureProvider.autoDispose<LpdpStats>((ref) async {
  final repo = ref.read(lpdpRepositoryProvider);
  return repo.getStats();
});

// ─── Provider: University Detail ──────────────────────────────────────────

final lpdpUnivDetailProvider =
    FutureProvider.autoDispose.family<LpdpUniversity, String>(
        (ref, name) async {
  final repo = ref.read(lpdpRepositoryProvider);
  return repo.getUniversityDetail(name);
});

// ─── Provider: Programs by Bidang ─────────────────────────────────────────

final lpdpBidangProgramsProvider =
    FutureProvider.autoDispose.family<List<LpdpProgram>, String>(
        (ref, bidang) async {
  final repo = ref.read(lpdpRepositoryProvider);
  return repo.getPrograms(bidang);
});

// ─── Provider: Search ─────────────────────────────────────────────────────

final lpdpSearchProvider =
    FutureProvider.autoDispose.family<List<LpdpProgram>, String>(
        (ref, query) async {
  final repo = ref.read(lpdpRepositoryProvider);
  return repo.search(query);
});

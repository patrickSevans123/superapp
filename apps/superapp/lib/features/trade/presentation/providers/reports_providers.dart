import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/api/reports_api_client.dart';
import '../../data/models/daily_report.dart';
import '../../data/models/research_report.dart';
import '../../data/models/research_report_source.dart';
import '../../data/repository/reports_repository.dart';

/// Provides the [ReportsApiClient] singleton using the shared auth-aware
/// Dio (so the JWT is attached automatically).
final reportsApiClientProvider = Provider<ReportsApiClient>((ref) {
  return ReportsApiClient(dio: ref.read(authDioProvider));
});

/// Provides the [ReportsRepository] singleton.
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(reportsApiClientProvider));
});

/// Latest daily report (or null if none published yet).  Used by the
/// "Today's Report" card on the trade dashboard.
final latestDailyReportProvider = FutureProvider.autoDispose<DailyReport?>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getLatestDailyReport();
});

/// All daily reports for the list screen.  Sorted newest-first by the
/// backend.
final dailyReportsProvider = FutureProvider.autoDispose<List<DailyReport>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.listDailyReports(limit: 50);
});

/// Research reports list, optionally filtered by [source].  Pass `null`
/// to get all sources.
final researchReportsProvider = FutureProvider.autoDispose
    .family<List<ResearchReport>, ResearchReportSource?>((ref, source) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.listResearchReports(source: source, limit: 50);
});

/// Single research report fetched by id (detail screen).
final researchReportProvider =
    FutureProvider.autoDispose.family<ResearchReport, String>((ref, id) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getResearchReport(id);
});

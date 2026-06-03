import '../api/reports_api_client.dart';
import '../models/daily_report.dart';
import '../models/research_report.dart';
import '../models/research_report_source.dart';

/// Repository that mediates between the [ReportsApiClient] and the rest of
/// the app.  Mirrors the pattern used by [TradeRepository].
class ReportsRepository {
  final ReportsApiClient _api;

  ReportsRepository(this._api);

  // ─── Daily reports ─────────────────────────────────────────────────────

  Future<List<DailyReport>> listDailyReports({int limit = 20}) {
    return _api.listDailyReports(limit: limit);
  }

  Future<DailyReport?> getLatestDailyReport() {
    return _api.getLatestDailyReport();
  }

  // ─── Research reports ──────────────────────────────────────────────────

  Future<List<ResearchReport>> listResearchReports({
    ResearchReportSource? source,
    int limit = 20,
  }) {
    return _api.listResearchReports(source: source, limit: limit);
  }

  Future<ResearchReport> getResearchReport(String id) {
    return _api.getResearchReport(id);
  }
}

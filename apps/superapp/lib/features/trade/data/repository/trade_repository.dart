import '../api/trade_api_client.dart';
import '../models/app_event.dart';
import '../models/market_quote.dart';
import '../models/models.dart';
import '../models/news_result.dart';
import '../models/news_status.dart';
import '../models/plans_summary.dart';
import '../models/scraper_health.dart';
import '../models/trading_plan.dart';

/// Repository that mediates between the [TradeApiClient] and the rest of
/// the app. Wraps API calls with consistent error handling.
class TradeRepository {
  final TradeApiClient _api;

  TradeRepository(this._api);

  // ─── Quotes ─────────────────────────────────────────────────────────

  /// Fetches a single market quote for the given [symbol].
  Future<MarketQuote> getQuote(String symbol) async {
    try {
      return await _api.getQuote(symbol);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches market quotes for the given list of [symbols].
  Future<List<MarketQuote>> getQuotes(List<String> symbols) async {
    try {
      return await _api.getQuotes(symbols);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Trading Plans ─────────────────────────────────────────────────

  /// Fetches trading plans, optionally filtered by [status].
  Future<List<TradingPlan>> getPlans({String? status}) async {
    try {
      return await _api.getPlans(status: status);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the trading plans summary.
  Future<PlansSummary> getPlansSummary() async {
    try {
      return await _api.getPlansSummary();
    } catch (e) {
      rethrow;
    }
  }

  // ─── News ───────────────────────────────────────────────────────────

  /// Fetches news items for a given [source]. Returns a [NewsResult]
  /// bundling the items with freshness metadata (age, count, mtime).
  Future<NewsResult> getNews({
    String source = 'bloomberg_english',
    int limit = 20,
  }) async {
    try {
      return await _api.getNews(source: source, limit: limit);
    } catch (e) {
      rethrow;
    }
  }

  /// Per-source freshness for every news scraper. Used by the trade
  /// dashboard and in-app notification banner.
  Future<NewsStatus> getNewsStatus() async {
    try {
      return await _api.getNewsStatus();
    } catch (e) {
      rethrow;
    }
  }

  /// Cross-system scraper health (news + MSCI + trading plans). Powers
  /// the "Data Stale" banner on the trade dashboard.
  Future<ScraperHealth> getScrapersHealth() async {
    try {
      return await _api.getScrapersHealth();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Events ─────────────────────────────────────────────────────────

  /// Fetches app events.
  Future<List<AppEvent>> getEvents() async {
    try {
      return await _api.getEvents();
    } catch (e) {
      rethrow;
    }
  }
}

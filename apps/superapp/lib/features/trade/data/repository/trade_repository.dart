import '../api/trade_api_client.dart';
import '../models/app_event.dart';
import '../models/briefing_model.dart';
import '../models/market_quote.dart';
import '../models/models.dart';
import '../models/news_result.dart';
import '../models/news_status.dart';
import '../models/plans_summary.dart';
import '../models/regime_model.dart';
import '../models/scraper_health.dart';
import '../models/decision_model.dart';
import '../models/signal_model.dart';
import '../models/trading_plan.dart';

/// Repository that mediates between the [TradeApiClient] and the rest of
/// the app. Wraps API calls with consistent error handling.
class TradeRepository {
  final TradeApiClient _api;

  TradeRepository(this._api);

  // ─── Quotes ─────────────────────────────────────────────────────────

  /// Fetches a single market quote for the given [symbol].
  Future<MarketQuote> getQuote(String symbol) => _api.getQuote(symbol);

  /// Fetches market quotes for the given list of [symbols].
  Future<List<MarketQuote>> getQuotes(List<String> symbols) =>
      _api.getQuotes(symbols);

  // ─── Trading Plans ─────────────────────────────────────────────────

  /// Fetches trading plans, optionally filtered by [status].
  Future<List<TradingPlan>> getPlans({String? status}) =>
      _api.getPlans(status: status);

  /// Fetches the trading plans summary.
  Future<PlansSummary> getPlansSummary() => _api.getPlansSummary();

  // ─── News ───────────────────────────────────────────────────────────

  /// Fetches news items for a given [source]. Returns a [NewsResult]
  /// bundling the items with freshness metadata (age, count, mtime).
  Future<NewsResult> getNews({
    String source = 'bloomberg_english',
    int limit = 20,
  }) =>
      _api.getNews(source: source, limit: limit);

  /// Per-source freshness for every news scraper. Used by the trade
  /// dashboard and in-app notification banner.
  Future<NewsStatus> getNewsStatus() => _api.getNewsStatus();

  /// Cross-system scraper health (news + MSCI + trading plans). Powers
  /// the "Data Stale" banner on the trade dashboard.
  Future<ScraperHealth> getScrapersHealth() => _api.getScrapersHealth();

  // ─── Signals ─────────────────────────────────────────────────────────

  /// Fetches trading signals for the given asset class.
  Future<List<SignalModel>> getSignals(String asset) =>
      _api.getSignals(asset);

  // ─── Regime ──────────────────────────────────────────────────────────

  /// Fetches the current market regime report.
  Future<RegimeReport> getRegime() => _api.getRegime();

  // ─── Briefing ────────────────────────────────────────────────────────

  /// Fetches today's morning briefing.
  Future<BriefingModel> getBriefing() => _api.getBriefing();

  // ─── Events ─────────────────────────────────────────────────────────

  /// Fetches app events.
  Future<List<AppEvent>> getEvents() => _api.getEvents();

  // ─── Decisions ───────────────────────────────────────────────────────

  /// Fetches trading decisions from the AI decision memory.
  Future<({List<DecisionModel> decisions, LearningStats stats})> getDecisions({
    String? ticker,
    int limit = 20,
    bool withReflections = false,
  }) =>
      _api.getDecisions(ticker: ticker, limit: limit, withReflections: withReflections);

  // ─── P2: Strategy Performance ──────────────────────────────────────

  /// Fetches all strategy backtest performance results.
  Future<List<StrategyPerformance>> getStrategyPerformance() =>
      _api.getStrategyPerformance();

  // ─── P2: Factor Scores ────────────────────────────────────────────

  /// Fetches composite factor scores for IDX stocks.
  Future<FactorResponse> getFactors() => _api.getFactors();
}

import '../../data/models/app_event.dart';
import '../../data/models/market_quote.dart';
import '../../data/models/news_item.dart';
import '../../data/models/plans_summary.dart';
import '../../data/models/trading_plan.dart';

/// Holds the state for the trade dashboard feature.
class TradeState {
  final List<TradingPlan> plans;
  final PlansSummary? summary;
  final List<NewsItem> news;
  final List<AppEvent> events;
  final MarketQuote? selectedQuote;
  final List<MarketQuote> quotes;
  final bool loading;
  final String? error;

  const TradeState({
    this.plans = const [],
    this.summary,
    this.news = const [],
    this.events = const [],
    this.selectedQuote,
    this.quotes = const [],
    this.loading = false,
    this.error,
  });

  TradeState copyWith({
    List<TradingPlan>? plans,
    PlansSummary? summary,
    List<NewsItem>? news,
    List<AppEvent>? events,
    MarketQuote? selectedQuote,
    List<MarketQuote>? quotes,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return TradeState(
      plans: plans ?? this.plans,
      summary: summary ?? this.summary,
      news: news ?? this.news,
      events: events ?? this.events,
      selectedQuote: selectedQuote ?? this.selectedQuote,
      quotes: quotes ?? this.quotes,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

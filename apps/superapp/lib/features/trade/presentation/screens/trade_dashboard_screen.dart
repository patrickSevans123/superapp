import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/router/app_routes.dart';
import '../../data/models/briefing_model.dart';
import '../../data/models/models.dart';
import '../providers/trade_providers.dart';
import '../widgets/charts/charts.dart';
import '../widgets/latest_report_banner.dart';
import '../widgets/plan_card.dart';
import '../widgets/stat_card.dart';

/// Dashboard screen for the trade feature.
///
/// Displays stat cards (Active, Win Rate, Avg Return, Total),
/// a list of active plans, and recent events.
class TradeDashboardScreen extends ConsumerStatefulWidget {
  const TradeDashboardScreen({super.key});

  @override
  ConsumerState<TradeDashboardScreen> createState() =>
      _TradeDashboardScreenState();
}

class _TradeDashboardScreenState extends ConsumerState<TradeDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  PlansSummary? _summary;
  List<TradingPlan> _activePlans = [];
  List<TradingPlan> _closedPlans = [];
  List<AppEvent> _events = [];
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(tradeRepositoryProvider);
      final results = await Future.wait([
        repo.getPlansSummary(),
        repo.getPlans(status: 'ACTIVE'),
        repo.getEvents(),
        repo.getPlans(status: 'CLOSED'),
      ]);
      setState(() {
        _summary = results[0] as PlansSummary;
        _activePlans = results[1] as List<TradingPlan>;
        _events = results[2] as List<AppEvent>;
        _closedPlans = results[3] as List<TradingPlan>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Could not load dashboard',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: 'Retry',
                onPressed: _loadData,
                icon: Icons.refresh,
                small: true,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildHeader(),
          _buildStaleBanner(),
          const SizedBox(height: 12),

          // ── Today's Report banner (gated by `new_report` preference) ───
          const LatestReportBanner(),
          const SizedBox(height: 12),

          if (_summary != null)
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Active',
                    value: '${_summary!.active}',
                    color: AppColors.accent,
                    icon: Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: 'Win Rate',
                    value:
                        '${_summary!.winRatePct.toStringAsFixed(0)}%',
                    color: AppColors.success,
                    icon: Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: 'Avg Return',
                    value:
                        '${_summary!.avgReturnPct.toStringAsFixed(1)}%',
                    color: _summary!.avgReturnPct >= 0
                        ? AppColors.success
                        : AppColors.error,
                    icon: Icons.show_chart,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: 'Total',
                    value: '${_summary!.total}',
                    icon: Icons.list,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Quick Actions ──────────────────────────────────────────────────
          Text(
            'Quick Actions',
            style: AppTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickActionsGrid(),

          // ── Performance Analytics ──────────────────────────────────────────
          const SizedBox(height: 16),
          Text(
            'Performance Analytics',
            style: AppTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_closedPlans.length >= 2) ...[
            PnlCurveChart(closedPlans: _closedPlans),
            const SizedBox(height: 16),
            DrawdownChart(closedPlans: _closedPlans),
            const SizedBox(height: 16),
            WinRateDonut(closedPlans: _closedPlans),
          ] else
            const EmptyChartPlaceholder(
              message: 'Charts appear after your first 2 closed trades.',
              height: 200,
            ),

          const SizedBox(height: 16),
          Text(
            'Active Plans',
            style: AppTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_activePlans.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No active plans',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.hint),
              ),
            )
          else
            ..._activePlans.map((p) => PlanCard(plan: p)),

          const SizedBox(height: 16),
          Text(
            'Recent Events',
            style: AppTextStyles.title.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._events.take(5).map(_buildEventTile),
        ],
      ),
    );
  }

  /// 2x2 grid of trade-section entry points.  The first cell stays
  /// gradient-styled (Trading Plans is the most-trafficked action);
  /// the other three use the secondary variant for visual rhythm.
  Widget _buildQuickActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SleekButton.gradient(
                label: 'Live Signals',
                onPressed: () => context.go(AppRoutes.tradeSignals),
                icon: Icons.signal_cellular_alt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SleekButton(
                label: 'Market Regime',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradeRegime),
                icon: Icons.analytics_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SleekButton(
                label: 'Trading Plans',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradePlans),
                icon: Icons.assignment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SleekButton(
                label: 'Market News',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradeNews),
                icon: Icons.newspaper,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SleekButton(
                label: 'AI Journal',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradeDecisions),
                icon: Icons.psychology_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SleekButton(
                label: 'Research',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradeResearch),
                icon: Icons.menu_book_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SleekButton(
                label: 'Factor Lab',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradeFactorLab),
                icon: Icons.science_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SleekButton(
                label: 'Portfolio',
                variant: SleekButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.tradePortfolioOptimize),
                icon: Icons.pie_chart_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GlassBox(
          radius: 14,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Self-Trade',
                style: AppTextStyles.headline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'AI Trading Intelligence',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.stone,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildBriefingCard(),
      ],
    );
  }

  Widget _buildBriefingCard() {
    final briefing = ref.watch(briefingProvider);
    return briefing.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (b) {
        if (b.isEmpty) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Morning Briefing',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(b.date, style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                b.body.length > 200 ? '${b.body.substring(0, 200)}...' : b.body,
                style: AppTextStyles.body.copyWith(fontSize: 13),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact "data stale" banner that surfaces the worst offending source
  /// across all scrapers (news + MSCI + plans). Hidden on load/error or
  /// when every source is healthy, and dismissible per-session via
  /// setState. Mirrors the colour scheme used by `news_freshness_banner.dart`.
  Widget _buildStaleBanner() {
    final health = ref.watch(scrapersHealthProvider);
    return health.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (h) {
        if (_dismissed || h.allHealthy) return const SizedBox.shrink();
        final worst = h.worstOffender;
        if (worst == null) return const SizedBox.shrink();
        final age = worst.ageLabel ?? '${worst.ageSeconds ?? 0}s';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ ${_humaniseSource(worst.source)} data stale — last update $age ago',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _dismissed = true),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: AppColors.stone),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _humaniseSource(String s) {
    switch (s) {
      case 'bloomberg_english':
        return 'Bloomberg English';
      case 'bloomberg_technoz':
        return 'Bloomberg Technoz';
      case 'reuters':
        return 'Reuters';
      default:
        return s;
    }
  }

  Widget _buildEventTile(AppEvent event) {
    final colors = {
      'success': AppColors.success,
      'danger': AppColors.error,
      'info': AppColors.accent,
    };
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.notifications,
          color: colors[event.severity] ?? AppColors.hint,
          size: 20,
        ),
        title: Text(
          event.title,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          event.body,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ),
    );
  }
}

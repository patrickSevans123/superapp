import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/errors/friendly_error.dart';
import '../../../../core/router/app_routes.dart';
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

class _TradeDashboardScreenState extends ConsumerState<TradeDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  PlansSummary? _summary;
  List<TradingPlan> _activePlans = [];
  List<TradingPlan> _closedPlans = [];
  List<AppEvent> _events = [];
  bool _dismissed = false;

  // Animation for staggered section entry
  late final AnimationController _staggerCtrl;
  late final Animation<double> _staggerFade;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _staggerFade = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
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
      // Trigger staggered entrance animation
      _staggerCtrl.forward();
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraMeshBackground(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: FadeTransition(
        opacity: _staggerFade,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 6),
            _buildStaleBanner(),
            const SizedBox(height: 6),

            // ── Today's Report banner ────────────────────────────────
            const LatestReportBanner(),
            const SizedBox(height: 8),

            // ── Stat Cards Row ───────────────────────────────────────
            if (_summary != null) _buildStatCardsRow(),

            const SizedBox(height: 20),

            // ── Quick Actions ────────────────────────────────────────
            _buildSectionHeader('Aksi Cepat'),
            const SizedBox(height: 10),
            _buildQuickActionsGrid(),

            // ── Performance Analytics ────────────────────────────────
            const SizedBox(height: 24),
            _buildSectionHeader('Analisis Performa'),
            const SizedBox(height: 10),
            if (_closedPlans.length >= 2) ...[
              PnlCurveChart(closedPlans: _closedPlans),
              const SizedBox(height: 12),
              DrawdownChart(closedPlans: _closedPlans),
              const SizedBox(height: 12),
              WinRateDonut(closedPlans: _closedPlans),
            ] else
              const EmptyChartPlaceholder(
                message: 'Chart muncul setelah 2 trade tertutup.',
                height: 200,
              ),

            const SizedBox(height: 24),
            _buildSectionHeader('Rencana Aktif'),
            const SizedBox(height: 10),
            if (_activePlans.isEmpty)
              _buildEmptyState(
                icon: Icons.assignment_outlined,
                message: 'Belum ada rencana aktif',
              )
            else
              ..._activePlans.map((p) => PlanCard(plan: p)),

            const SizedBox(height: 24),
            _buildSectionHeader('Event Terbaru'),
            const SizedBox(height: 10),
            if (_events.isEmpty)
              _buildEmptyState(
                icon: Icons.notifications_none,
                message: 'Belum ada event',
              )
            else
              ..._events.take(5).map(_buildEventTile),
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat dashboard',
              style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.stone),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Coba Lagi',
              onPressed: _loadData,
              icon: Icons.refresh,
              small: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.title.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.2,
      ),
    );
  }

  // ── Stat Cards Row ────────────────────────────────────────────────────

  Widget _buildStatCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _PolishedStatCard(
            label: 'Aktif',
            value: '${_summary!.active}',
            color: AppColors.accent,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PolishedStatCard(
            label: 'Win Rate',
            value: '${_summary!.winRatePct.toStringAsFixed(0)}%',
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PolishedStatCard(
            label: 'Avg Return',
            value: '${_summary!.avgReturnPct.toStringAsFixed(1)}%',
            color: _summary!.avgReturnPct >= 0
                ? AppColors.bullish
                : AppColors.bearish,
            icon: _summary!.avgReturnPct >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PolishedStatCard(
            label: 'Total',
            value: '${_summary!.total}',
            color: AppColors.stone,
            icon: Icons.list_rounded,
          ),
        ),
      ],
    );
  }

  // ── Quick Actions Grid (2×4) ──────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction('Live Signals', Icons.signal_cellular_alt_rounded,
          () => context.go(AppRoutes.tradeSignals), highlighted: true),
      _QuickAction('Market Regime', Icons.analytics_outlined,
          () => context.go(AppRoutes.tradeRegime)),
      _QuickAction('Trading Plans', Icons.assignment_rounded,
          () => context.go(AppRoutes.tradePlans)),
      _QuickAction('Market News', Icons.newspaper_rounded,
          () => context.go(AppRoutes.tradeNews)),
      _QuickAction('AI Journal', Icons.psychology_outlined,
          () => context.go(AppRoutes.tradeDecisions)),
      _QuickAction('Research', Icons.menu_book_outlined,
          () => context.go(AppRoutes.tradeResearch)),
      _QuickAction('Factor Lab', Icons.science_outlined,
          () => context.go(AppRoutes.tradeFactorLab)),
      _QuickAction('Portfolio', Icons.pie_chart_outline_rounded,
          () => context.go(AppRoutes.tradePortfolioOptimize)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        return _QuickActionTile(
          label: action.label,
          icon: action.icon,
          onTap: action.onTap,
          highlighted: action.highlighted,
        );
      },
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.hint),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.hint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        GlassBox(
          radius: 12,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Brand mark
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Self-Trade',
                      style: AppTextStyles.headline.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
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
              // Live indicator
              PulseDot(color: AppColors.success, size: 8),
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
                  const Icon(Icons.wb_sunny_outlined,
                      size: 16, color: AppColors.accent),
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
                b.body.length > 200
                    ? '${b.body.substring(0, 200)}...'
                    : b.body,
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

  // ── Stale Banner ──────────────────────────────────────────────────────

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
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_humaniseSource(worst.source)} data stale — update terakhir $age lalu',
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
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: AppColors.stone),
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

  // ── Event Tile ────────────────────────────────────────────────────────

  Widget _buildEventTile(AppEvent event) {
    final colors = {
      'success': AppColors.success,
      'danger': AppColors.error,
      'info': AppColors.accent,
    };
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (colors[event.severity] ?? AppColors.hint).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: colors[event.severity] ?? AppColors.hint,
              size: 18,
            ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

class _QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _QuickAction(this.label, this.icon, this.onTap, {this.highlighted = false});
}

/// Polished stat card with icon, value, and label — aligned with Garuda Dark spec.
class _PolishedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _PolishedStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.monoBody.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.stone,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Quick-action tile — icon + label in a compact grid cell.
class _QuickActionTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: widget.highlighted
                ? AppColors.accent.withOpacity(0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.highlighted
                  ? AppColors.accent.withOpacity(0.30)
                  : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.highlighted ? AppColors.accent : AppColors.stone,
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: widget.highlighted ? AppColors.accent : AppColors.stone,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

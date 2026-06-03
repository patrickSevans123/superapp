import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/regime_model.dart';
import '../providers/trade_providers.dart';

/// Screen showing market regime detection with HMM posteriors and allocation.
class RegimeScreen extends ConsumerStatefulWidget {
  const RegimeScreen({super.key});

  @override
  ConsumerState<RegimeScreen> createState() => _RegimeScreenState();
}

class _RegimeScreenState extends ConsumerState<RegimeScreen> {
  @override
  Widget build(BuildContext context) {
    final regimeAsync = ref.watch(regimeProvider);
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const GlassAppBar(title: 'Market Regime'),
        body: regimeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Failed to load regime', style: AppTextStyles.body),
                const SizedBox(height: 12),
                SleekButton(
                  label: 'Retry',
                  variant: SleekButtonVariant.secondary,
                  onPressed: () => ref.invalidate(regimeProvider),
                  small: true,
                ),
              ],
            ),
          ),
          data: (report) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(regimeProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _GlobalRegime(regime: report.globalRegime),
                const SizedBox(height: 16),
                if (report.perAsset.isNotEmpty) ...[
                  Text('Per-asset regimes',
                      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final ar in report.perAsset)
                    _AssetRegimeCard(assetRegime: ar),
                ],
                const SizedBox(height: 16),
                if (report.allocation.isNotEmpty) ...[
                  Text('Recommended allocation',
                      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _AllocationPieCard(slices: report.allocation),
                ],
                const SizedBox(height: 16),
                _MltGauge(
                  mltPct: report.maxLossTolerancePct,
                  drawdownPct: report.currentDrawdownPct,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Global Regime Hero ────────────────────────────────────────────────────

class _GlobalRegime extends StatelessWidget {
  const _GlobalRegime({required this.regime});
  final Regime regime;

  @override
  Widget build(BuildContext context) {
    final color = _regimeColor(regime);
    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_regimeIcon(regime), color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Global regime', style: AppTextStyles.caption),
                Text(regime.id,
                    style: AppTextStyles.display.copyWith(
                        color: color, fontWeight: FontWeight.w800)),
                Text(regime.tagline, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-Asset Regime Card ─────────────────────────────────────────────────

class _AssetRegimeCard extends StatelessWidget {
  const _AssetRegimeCard({required this.assetRegime});
  final AssetRegime assetRegime;

  @override
  Widget build(BuildContext context) {
    final color = _regimeColor(assetRegime.regime);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(assetRegime.asset,
                  style: AppTextStyles.headline.copyWith(color: color)),
              const SizedBox(width: 8),
              Text(assetRegime.regime.id, style: AppTextStyles.label),
              const Spacer(),
              Text('vol q= ${assetRegime.volQuantile.toStringAsFixed(2)}',
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in assetRegime.posteriors.entries)
            _PosteriorRow(regime: e.key, p: e.value),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Vol quantile', style: AppTextStyles.caption),
              const Spacer(),
              Text('${(assetRegime.volQuantile * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: assetRegime.volQuantile.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosteriorRow extends StatelessWidget {
  const _PosteriorRow({required this.regime, required this.p});
  final Regime regime;
  final double p;

  @override
  Widget build(BuildContext context) {
    final c = _regimeColor(regime);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(regime.id,
                style: AppTextStyles.caption.copyWith(color: c)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: p.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: c.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(p.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: AppTextStyles.label),
          ),
        ],
      ),
    );
  }
}

// ── Allocation Pie ────────────────────────────────────────────────────────

class _AllocationPieCard extends StatelessWidget {
  const _AllocationPieCard({required this.slices});
  final List<AllocationSlice> slices;

  static const _colors = [
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  for (var i = 0; i < slices.length; i++)
                    PieChartSectionData(
                      color: _colors[i % _colors.length],
                      value: slices[i].weight * 100,
                      title: '${(slices[i].weight * 100).toStringAsFixed(0)}%',
                      radius: 32,
                      titleStyle: AppTextStyles.caption
                          .copyWith(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < slices.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(slices[i].strategy,
                              style: AppTextStyles.body),
                        ),
                        Text('${(slices[i].weight * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.label),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MLT Gauge ─────────────────────────────────────────────────────────────

class _MltGauge extends StatelessWidget {
  const _MltGauge({required this.mltPct, required this.drawdownPct});
  final double mltPct;
  final double drawdownPct;

  @override
  Widget build(BuildContext context) {
    final usage = (drawdownPct / mltPct).clamp(0.0, 1.0);
    final color = usage < 0.5
        ? AppColors.success
        : usage < 0.8
            ? AppColors.warning
            : AppColors.error;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Drawdown', style: AppTextStyles.title),
              const Spacer(),
              Text(
                '${drawdownPct.toStringAsFixed(2)}% / ${mltPct.toStringAsFixed(1)}%',
                style: AppTextStyles.headline.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usage,
              minHeight: 16,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            usage < 0.8
                ? 'Within tolerance — keep current sizing.'
                : 'Approaching MLT — consider de-risking.',
            style: AppTextStyles.body.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────

Color _regimeColor(Regime r) => switch (r) {
      Regime.bull => AppColors.success,
      Regime.choppy => AppColors.warning,
      Regime.highVolTrend => AppColors.accent,
      Regime.crisis => AppColors.error,
    };

IconData _regimeIcon(Regime r) => switch (r) {
      Regime.bull => Icons.trending_up,
      Regime.choppy => Icons.waves,
      Regime.highVolTrend => Icons.bolt,
      Regime.crisis => Icons.warning_amber_rounded,
    };

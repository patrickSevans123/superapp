import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/factor_model.dart';
import '../../data/models/strategy_performance.dart';
import '../providers/trade_providers.dart';
import '../widgets/stat_card.dart';

/// Factor Lab — strategy performance comparison + factor analysis screen.
///
/// Shows:
/// 1. Strategy performance leaderboard (Sharpe, MDD, return)
/// 2. Factor heatmap (size, value, liquidity, momentum)
/// 3. Factor ranking table with composite scores
class FactorLabScreen extends ConsumerWidget {
  const FactorLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strategyAsync = ref.watch(strategyPerformanceProvider);
    final factorsAsync = ref.watch(factorsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Factor Lab'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(strategyPerformanceProvider);
          ref.invalidate(factorsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Strategy Performance Section ──
            _buildSectionHeader('Strategy Performance'),
            const SizedBox(height: 8),
            strategyAsync.when(
              data: (strategies) => _buildStrategyList(strategies),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),

            const SizedBox(height: 24),

            // ── Factor Heatmap Section ──
            _buildSectionHeader('Factor Heatmap'),
            const SizedBox(height: 8),
            factorsAsync.when(
              data: (response) => _buildFactorHeatmap(response),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),

            const SizedBox(height: 24),

            // ── Factor Ranking Section ──
            _buildSectionHeader('Factor Rankings'),
            const SizedBox(height: 8),
            factorsAsync.when(
              data: (response) => _buildFactorRanking(response),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  // ─── Strategy Performance List ──────────────────────────────────────

  Widget _buildStrategyList(List<StrategyPerformance> strategies) {
    if (strategies.isEmpty) {
      return const _EmptyCard(message: 'No strategy data available');
    }

    return Column(
      children: strategies.map((s) => _StrategyCard(strategy: s)).toList(),
    );
  }

  // ─── Factor Heatmap ─────────────────────────────────────────────────

  Widget _buildFactorHeatmap(FactorResponse response) {
    if (response.factors.isEmpty) {
      return const _EmptyCard(message: 'No factor data available');
    }

    // Take top 10 for heatmap
    final top10 = response.factors.take(10).toList();

    return Container(
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response.methodology,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              _heatmapHeader('Ticker'),
              _heatmapHeader('Size'),
              _heatmapHeader('Value'),
              _heatmapHeader('Liq'),
              _heatmapHeader('Mom'),
              _heatmapHeader('Comp'),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          // Data rows
          ...top10.map((f) => _buildHeatmapRow(f)),
        ],
      ),
    );
  }

  Widget _heatmapHeader(String label) {
    return Expanded(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHeatmapRow(FactorScore factor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              factor.ticker,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          _heatmapCell(factor.size),
          _heatmapCell(factor.value),
          _heatmapCell(factor.liquidity),
          _heatmapCell(factor.momentum),
          _heatmapCell(factor.composite),
        ],
      ),
    );
  }

  Widget _heatmapCell(double value) {
    final color = _factorColor(value);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Color _factorColor(double value) {
    if (value > 0.3) return const Color(0xFF4CAF50); // Green
    if (value > 0) return const Color(0xFF8BC34A); // Light green
    if (value > -0.3) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  // ─── Factor Ranking Table ──────────────────────────────────────────

  Widget _buildFactorRanking(FactorResponse response) {
    if (response.factors.isEmpty) {
      return const _EmptyCard(message: 'No factor data available');
    }

    return Container(
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              _rankHeader('#', 30),
              _rankHeader('Ticker', 60),
              _rankHeader('Composite', 70),
              _rankHeader('Size', 50),
              _rankHeader('Value', 50),
              _rankHeader('Liquidity', 60),
              _rankHeader('Momentum', 65),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          // Top 15 ranked
          ...response.factors.take(15).map((f) => _buildRankRow(f)),
        ],
      ),
    );
  }

  Widget _rankHeader(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRankRow(FactorScore factor) {
    final isTop3 = factor.rank <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isTop3
          ? BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${factor.rank}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w400,
                color: isTop3 ? Colors.amber : Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              factor.ticker,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: _scoreChip(factor.composite),
          ),
          SizedBox(
            width: 50,
            child: Text(
              factor.size.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 11,
                color: _factorColor(factor.size),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              factor.value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 11,
                color: _factorColor(factor.value),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              factor.liquidity.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 11,
                color: _factorColor(factor.liquidity),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 65,
            child: Text(
              factor.momentum.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 11,
                color: _factorColor(factor.momentum),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(double score) {
    final color = _factorColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        score.toStringAsFixed(3),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1,
      ),
    );
  }
}

// ─── Strategy Card ────────────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final StrategyPerformance strategy;

  const _StrategyCard({required this.strategy});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showStrategyDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strategy.method,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SharpeBadge(sharpe: strategy.avgSharpe),
                ],
              ),

              const SizedBox(height: 12),

              // Metrics row
              Row(
                children: [
                  _MetricChip(
                    label: 'Sharpe',
                    value: strategy.avgSharpe.toStringAsFixed(2),
                    color: _sharpeColor(strategy.avgSharpe),
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'MDD',
                    value: '${(strategy.avgMdd * 100).toStringAsFixed(1)}%',
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'Return',
                    value: '${(strategy.avgReturn * 100).toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'Assets',
                    value: '${strategy.nTickers}',
                    color: Colors.blue,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Tickers
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: strategy.tickers.take(8).map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStrategyDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _StrategyDetailSheet(strategy: strategy),
    );
  }

  Color _sharpeColor(double sharpe) {
    if (sharpe >= 1.5) return const Color(0xFF4CAF50);
    if (sharpe >= 1.0) return const Color(0xFF8BC34A);
    if (sharpe >= 0.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

// ─── Sharpe Badge ─────────────────────────────────────────────────────

class _SharpeBadge extends StatelessWidget {
  final double sharpe;

  const _SharpeBadge({required this.sharpe});

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            sharpe.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            _label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    if (sharpe >= 1.5) return 'EXCELLENT';
    if (sharpe >= 1.0) return 'GOOD';
    if (sharpe >= 0.5) return 'FAIR';
    return 'POOR';
  }

  Color get _color {
    if (sharpe >= 1.5) return const Color(0xFF4CAF50);
    if (sharpe >= 1.0) return const Color(0xFF8BC34A);
    if (sharpe >= 0.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

// ─── Metric Chip ──────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Strategy Detail Sheet ────────────────────────────────────────────

class _StrategyDetailSheet extends StatelessWidget {
  final StrategyPerformance strategy;

  const _StrategyDetailSheet({required this.strategy});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strategy.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strategy.method,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Summary metrics
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Sharpe', value: strategy.avgSharpe.toStringAsFixed(3))),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(label: 'MDD', value: '${(strategy.avgMdd * 100).toStringAsFixed(1)}%')),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(label: 'Return', value: '${(strategy.avgReturn * 100).toStringAsFixed(1)}%')),
                ],
              ),

              const SizedBox(height: 20),
              const Text(
                'Per-Asset Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Per-asset table
              ...strategy.perAsset.entries.map((entry) {
                final asset = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _assetMetric('Sharpe', asset.sharpe.toStringAsFixed(2)),
                      _assetMetric('MDD', '${(asset.mdd * 100).toStringAsFixed(1)}%'),
                      _assetMetric('Return', '${(asset.totalReturn * 100).toStringAsFixed(1)}%'),
                      _assetMetric('Trades', '${asset.nTrades}'),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _assetMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

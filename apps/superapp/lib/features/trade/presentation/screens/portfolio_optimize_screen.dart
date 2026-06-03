import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/portfolio_model.dart';
import '../providers/trade_providers.dart';

/// P3: Portfolio Optimization screen.
///
/// Shows:
/// 1. Efficient frontier scatter plot (risk vs return)
/// 2. Optimal portfolio allocation (pie chart)
/// 3. Min-variance portfolio allocation
/// 4. Individual asset stats table
class PortfolioOptimizeScreen extends ConsumerWidget {
  const PortfolioOptimizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioOptimizeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Portfolio Optimizer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(portfolioOptimizeProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            portfolioAsync.when(
              data: (data) => _buildContent(data),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PortfolioOptimizeResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Efficient Frontier Chart ──
        _buildSectionHeader('Efficient Frontier'),
        const SizedBox(height: 8),
        _EfficientFrontierChart(
          points: data.efficientFrontier,
          optimal: data.optimalPortfolio,
          minVariance: data.minVariancePortfolio,
          assets: data.individualAssets,
        ),

        const SizedBox(height: 24),

        // ── Optimal Portfolio ──
        _buildSectionHeader('Optimal Portfolio (Max Sharpe)'),
        const SizedBox(height: 8),
        _AllocationCard(
          allocation: data.optimalPortfolio,
          color: const Color(0xFF4CAF50),
          label: 'Maximum Sharpe Ratio',
        ),

        const SizedBox(height: 16),

        // ── Min Variance Portfolio ──
        _buildSectionHeader('Minimum Variance Portfolio'),
        const SizedBox(height: 8),
        _AllocationCard(
          allocation: data.minVariancePortfolio,
          color: const Color(0xFF2196F3),
          label: 'Lowest Risk',
        ),

        const SizedBox(height: 24),

        // ── Individual Assets ──
        _buildSectionHeader('Individual Assets'),
        const SizedBox(height: 8),
        _AssetStatsTable(assets: data.individualAssets),

        const SizedBox(height: 16),

        // ── Metadata ──
        _MetadataBar(metadata: data.metadata),

        const SizedBox(height: 32),
      ],
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
}

// ─── Efficient Frontier Chart ────────────────────────────────────────

class _EfficientFrontierChart extends StatelessWidget {
  final List<EfficientFrontierPoint> points;
  final PortfolioAllocation optimal;
  final PortfolioAllocation minVariance;
  final List<AssetStats> assets;

  const _EfficientFrontierChart({
    required this.points,
    required this.optimal,
    required this.minVariance,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        size: const Size(double.infinity, 250),
        painter: _FrontierPainter(
          points: points,
          optimal: optimal,
          minVariance: minVariance,
          assets: assets,
        ),
      ),
    );
  }
}

class _FrontierPainter extends CustomPainter {
  final List<EfficientFrontierPoint> points;
  final PortfolioAllocation optimal;
  final PortfolioAllocation minVariance;
  final List<AssetStats> assets;

  _FrontierPainter({
    required this.points,
    required this.optimal,
    required this.minVariance,
    required this.assets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && assets.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Find bounds
    double maxRisk = 0, maxReturn = 0, minReturn = 999;
    for (final p in points) {
      if (p.risk > maxRisk) maxRisk = p.risk;
      if (p.ret > maxReturn) maxReturn = p.ret;
      if (p.ret < minReturn) minReturn = p.ret;
    }
    for (final a in assets) {
      if (a.risk > maxRisk) maxRisk = a.risk;
      if (a.ret > maxReturn) maxReturn = a.ret;
      if (a.ret < minReturn) minReturn = a.ret;
    }
    if (maxRisk == 0) maxRisk = 0.3;
    if (maxReturn == minReturn) maxReturn = minReturn + 0.1;

    // Add margin
    maxRisk *= 1.1;
    maxReturn *= 1.1;
    minReturn = math.min(minReturn * 0.9, 0);

    double toX(double risk) => padding + (risk / maxRisk) * chartWidth;
    double toY(double ret) => padding + chartHeight - ((ret - minReturn) / (maxReturn - minReturn)) * chartHeight;

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padding, padding), Offset(padding, size.height - padding), axisPaint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(size.width - padding, size.height - padding), axisPaint);

    // Axis labels
    final labelStyle = TextStyle(fontSize: 10, color: Colors.white54);
    // Y-axis: return percentages
    for (int i = 0; i <= 4; i++) {
      final ret = minReturn + (maxReturn - minReturn) * i / 4;
      final y = toY(ret);
      final tp = TextPainter(
        text: TextSpan(text: '${(ret * 100).toStringAsFixed(0)}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padding - tp.width - 4, y - tp.height / 2));
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), Paint()..color = Colors.white12);
    }
    // X-axis: risk percentages
    for (int i = 0; i <= 4; i++) {
      final risk = maxRisk * i / 4;
      final x = toX(risk);
      final tp = TextPainter(
        text: TextSpan(text: '${(risk * 100).toStringAsFixed(0)}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding + 4));
    }

    // Axis titles
    final titleStyle = TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600);
    final yTitle = TextPainter(
      text: TextSpan(text: 'Return', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    yTitle.paint(canvas, Offset(2, size.height / 2 - yTitle.height / 2));

    final xTitle = TextPainter(
      text: TextSpan(text: 'Risk', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    xTitle.paint(canvas, Offset(size.width / 2 - xTitle.width / 2, size.height - 12));

    // Draw scatter points (efficient frontier)
    final pointPaint = Paint()..color = Colors.white24;
    for (final p in points) {
      canvas.drawCircle(Offset(toX(p.risk), toY(p.ret)), 2, pointPaint);
    }

    // Draw efficient frontier line
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF00BCD4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(toX(points.first.risk), toY(points.first.ret));
      for (int i = 1; i < points.length; i++) {
        path.lineTo(toX(points[i].risk), toY(points[i].ret));
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw individual assets (blue dots)
    final assetPaint = Paint()..color = const Color(0xFF2196F3);
    for (final a in assets) {
      canvas.drawCircle(Offset(toX(a.risk), toY(a.ret)), 5, assetPaint);
      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: a.ticker,
          style: TextStyle(fontSize: 9, color: Colors.white70),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(toX(a.risk) + 7, toY(a.ret) - tp.height / 2));
    }

    // Draw optimal portfolio (green star)
    final optimalPaint = Paint()..color = const Color(0xFF4CAF50);
    final ox = toX(optimal.risk);
    final oy = toY(optimal.ret);
    _drawStar(canvas, ox, oy, 8, optimalPaint);
    final optLabel = TextPainter(
      text: TextSpan(
        text: 'OPTIMAL',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    optLabel.paint(canvas, Offset(ox + 10, oy - optLabel.height / 2));

    // Draw min-variance (blue star)
    final minPaint = Paint()..color = const Color(0xFF2196F3);
    final mx = toX(minVariance.risk);
    final my = toY(minVariance.ret);
    _drawStar(canvas, mx, my, 8, minPaint);
    final minLabel = TextPainter(
      text: TextSpan(
        text: 'MIN VAR',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2196F3)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    minLabel.paint(canvas, Offset(mx + 10, my - minLabel.height / 2));
  }

  void _drawStar(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Allocation Card ─────────────────────────────────────────────────

class _AllocationCard extends StatelessWidget {
  final PortfolioAllocation allocation;
  final Color color;
  final String label;

  const _AllocationCard({
    required this.allocation,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const Spacer(),
              _MetricPill(label: 'Return', value: '${(allocation.ret * 100).toStringAsFixed(1)}%', color: Colors.green),
              const SizedBox(width: 6),
              _MetricPill(label: 'Risk', value: '${(allocation.risk * 100).toStringAsFixed(1)}%', color: Colors.orange),
              const SizedBox(width: 6),
              _MetricPill(label: 'Sharpe', value: allocation.sharpe.toStringAsFixed(2), color: color),
            ],
          ),
          const SizedBox(height: 12),
          // Allocation bars
          ...allocation.allocations.map((a) => _AllocationBar(item: a, color: color)),
        ],
      ),
    );
  }
}

class _AllocationBar extends StatelessWidget {
  final AllocationItem item;
  final Color color;

  const _AllocationBar({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              item.ticker,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.weight,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
                minHeight: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text(
              '${(item.weight * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

// ─── Asset Stats Table ───────────────────────────────────────────────

class _AssetStatsTable extends StatelessWidget {
  final List<AssetStats> assets;

  const _AssetStatsTable({required this.assets});

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const _EmptyCard(message: 'No asset data');

    // Sort by Sharpe descending
    final sorted = List<AssetStats>.from(assets)..sort((a, b) => b.sharpe.compareTo(a.sharpe));

    return Container(
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              _tableHeader('Ticker', 60),
              _tableHeader('Return', 65),
              _tableHeader('Risk', 65),
              _tableHeader('Sharpe', 65),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          ...sorted.take(15).map((a) => _buildAssetRow(a)),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7)),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAssetRow(AssetStats asset) {
    final sharpeColor = _sharpeColor(asset.sharpe);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              asset.ticker,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          SizedBox(
            width: 65,
            child: Text(
              '${(asset.ret * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: asset.ret >= 0 ? Colors.green : Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 65,
            child: Text(
              '${(asset.risk * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 65,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: sharpeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                asset.sharpe.toStringAsFixed(2),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sharpeColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _sharpeColor(double sharpe) {
    if (sharpe >= 1.5) return const Color(0xFF4CAF50);
    if (sharpe >= 1.0) return const Color(0xFF8BC34A);
    if (sharpe >= 0.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

// ─── Metadata Bar ────────────────────────────────────────────────────

class _MetadataBar extends StatelessWidget {
  final PortfolioMetadata metadata;

  const _MetadataBar({required this.metadata});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _glassDecoration(),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _metaItem('Assets', '${metadata.tickers.length}'),
          _metaItem('Simulations', '${metadata.nPortfolios}'),
          _metaItem('Risk-Free', '${(metadata.riskFreeRate * 100).toStringAsFixed(0)}%'),
          _metaItem('Data Days', '${metadata.dataPoints}'),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────

BoxDecoration _glassDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _glassDecoration(),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Optimizing portfolio...', style: TextStyle(color: Colors.white54)),
            SizedBox(height: 8),
            Text('Running Monte Carlo simulation', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
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
      child: Text(message, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
      decoration: _glassDecoration(),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
      ),
    );
  }
}

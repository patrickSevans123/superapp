import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/signal_model.dart';
import '../providers/trade_providers.dart';

/// Screen showing live trading signals with IDX / US / Crypto tabs.
class SignalsScreen extends ConsumerStatefulWidget {
  const SignalsScreen({super.key});

  @override
  ConsumerState<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends ConsumerState<SignalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: AssetClass.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: 'Live Signals',
          bottom: TabBar(
            controller: _tabController,
            tabs: [for (final a in AssetClass.values) Tab(text: a.label)],
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.title,
            unselectedLabelStyle: AppTextStyles.title,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final a in AssetClass.values)
              _SignalsTab(asset: a),
          ],
        ),
      ),
    );
  }
}

class _SignalsTab extends ConsumerWidget {
  const _SignalsTab({required this.asset});
  final AssetClass asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(signalsProvider(asset.id));
    return signalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load signals', style: AppTextStyles.body),
            const SizedBox(height: 12),
            SleekButton(
              label: 'Retry',
              variant: SleekButtonVariant.secondary,
              onPressed: () => ref.invalidate(signalsProvider(asset.id)),
              small: true,
            ),
          ],
        ),
      ),
      data: (signals) {
        if (signals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.signal_cellular_alt, size: 48, color: AppColors.hint),
                const SizedBox(height: 16),
                Text('No signals yet', style: AppTextStyles.body),
                const SizedBox(height: 4),
                Text('Run the daemon to generate signals',
                    style: AppTextStyles.caption),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(signalsProvider(asset.id)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: signals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SignalCard(signal: signals[i], index: i + 1),
          ),
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal, required this.index});
  final SignalModel signal;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = _sentimentColor(signal.sentiment);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Text('$index',
                style: AppTextStyles.label.copyWith(color: color)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(signal.name,
                    style: AppTextStyles.title),
              ),
              Text(signal.emoji, style: const TextStyle(fontSize: 18)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(signal.value,
                style: AppTextStyles.headline.copyWith(color: color)),
          ),
          children: [
            _StrengthBar(value: signal.strength, color: color),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (signal.paper != null && signal.paper!.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 14),
                    label: Text(signal.paper!),
                    visualDensity: VisualDensity.compact,
                  ),
                if (signal.sharpe != null)
                  _MiniMetric(
                      label: 'Sharpe',
                      value: signal.sharpe!.toStringAsFixed(2)),
                if (signal.hitRate != null)
                  _MiniMetric(
                      label: 'Hit',
                      value: '${(signal.hitRate! * 100).toStringAsFixed(0)}%'),
              ],
            ),
            if (signal.series30d.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MiniChart(series: signal.series30d, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

Color _sentimentColor(String sentiment) => switch (sentiment) {
      'bullish' => AppColors.success,
      'bearish' => AppColors.error,
      _ => AppColors.warning,
    };

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Signal strength', style: AppTextStyles.caption),
              const Spacer(),
              Text('${(value * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(width: 6),
            Text(value, style: AppTextStyles.label),
          ],
        ),
      );
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.series, required this.color});
  final List<double> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final spots = [
      for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i]),
    ];
    final minY = series.reduce((a, b) => a < b ? a : b);
    final maxY = series.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 90,
      child: LineChart(
        LineChartData(
          minY: minY - 0.02,
          maxY: maxY + 0.02,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

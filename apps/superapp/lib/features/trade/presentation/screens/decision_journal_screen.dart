import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/decision_model.dart';
import '../providers/trade_providers.dart';

/// AI Trading Journal showing decisions with LLM reflections.
class DecisionJournalScreen extends ConsumerStatefulWidget {
  const DecisionJournalScreen({super.key});

  @override
  ConsumerState<DecisionJournalScreen> createState() => _DecisionJournalScreenState();
}

class _DecisionJournalScreenState extends ConsumerState<DecisionJournalScreen> {
  String? _filterTicker;

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider(_filterTicker));
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: 'AI Trading Journal',
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: _showFilterSheet,
              tooltip: 'Filter by ticker',
            ),
          ],
        ),
        body: decisionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Failed to load decisions', style: AppTextStyles.body),
                const SizedBox(height: 12),
                SleekButton(
                  label: 'Retry',
                  variant: SleekButtonVariant.secondary,
                  onPressed: () => ref.invalidate(decisionsProvider(_filterTicker)),
                  small: true,
                ),
              ],
            ),
          ),
          data: (result) {
            final stats = result.stats;
            final decisions = result.decisions;
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(decisionsProvider(_filterTicker)),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Learning Stats Card
                  _LearningStatsCard(stats: stats),
                  const SizedBox(height: 16),
                  // Filter chip
                  if (_filterTicker != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Chip(
                        label: Text('Filtered: $_filterTicker'),
                        onDeleted: () => setState(() => _filterTicker = null),
                      ),
                    ),
                  // Decision Timeline
                  if (decisions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.psychology_outlined, size: 48, color: AppColors.hint),
                            const SizedBox(height: 16),
                            Text('No decisions yet', style: AppTextStyles.body),
                            const SizedBox(height: 4),
                            Text('Decisions appear after the daemon runs',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < decisions.length; i++)
                      _DecisionCard(
                        decision: decisions[i],
                        index: i,
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by ticker', style: AppTextStyles.title),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'e.g. BBCA, TLKM',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                Navigator.pop(context);
                setState(() => _filterTicker = value.toUpperCase());
              },
            ),
            const SizedBox(height: 8),
            SleekButton(
              label: 'Show All',
              variant: SleekButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _filterTicker = null);
              },
              small: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Learning Stats Card ──────────────────────────────────────────────────

class _LearningStatsCard extends StatelessWidget {
  const _LearningStatsCard({required this.stats});
  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning Stats', style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem(label: 'Total', value: '${stats.totalDecisions}', color: AppColors.accent),
              const SizedBox(width: 16),
              _StatItem(label: 'Win Rate', value: '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  color: stats.winRate > 0.5 ? AppColors.success : AppColors.error),
              const SizedBox(width: 16),
              _StatItem(label: 'Avg Return', value: '${(stats.avgReturn * 100).toStringAsFixed(1)}%',
                  color: stats.avgReturn > 0 ? AppColors.success : AppColors.error),
              const SizedBox(width: 16),
              _StatItem(label: 'Avg Alpha', value: '${(stats.avgAlpha * 100).toStringAsFixed(1)}%',
                  color: stats.avgAlpha > 0 ? AppColors.success : AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: AppTextStyles.headline.copyWith(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
      ],
    ),
  );
}

// ── Decision Card ────────────────────────────────────────────────────────

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.decision, required this.index});
  final DecisionModel decision;
  final int index;

  @override
  Widget build(BuildContext context) {
    final actionColor = switch (decision.action.toUpperCase()) {
      'BUY' => AppColors.success,
      'SELL' => AppColors.error,
      _ => AppColors.warning,
    };
    final returnColor = (decision.realizedReturn ?? 0) >= 0
        ? AppColors.success
        : AppColors.error;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: actionColor.withValues(alpha: 0.18),
            child: Text(decision.actionEmoji, style: const TextStyle(fontSize: 16)),
          ),
          title: Row(
            children: [
              Text(decision.ticker, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(decision.action, style: AppTextStyles.caption.copyWith(color: actionColor)),
              ),
              const Spacer(),
              if (decision.isClosed && decision.realizedReturn != null)
                Text('${(decision.realizedReturn! * 100).toStringAsFixed(1)}%',
                    style: AppTextStyles.label.copyWith(color: returnColor)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Entry: ${decision.entryPrice.toStringAsFixed(0)} • ${decision.horizon} • ${(decision.confidence * 100).toStringAsFixed(0)}% confidence',
              style: AppTextStyles.caption,
            ),
          ),
          children: [
            // Reasoning
            if (decision.reasoning.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('Reasoning', style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 4),
              Text(decision.reasoning, style: AppTextStyles.body),
              const SizedBox(height: 12),
            ],
            // AI Reflection
            if (decision.reflection != null && decision.reflection!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text('AI Reflection', style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(decision.reflection!, style: AppTextStyles.body),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Trade details
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _DetailChip(label: 'Entry', value: decision.entryPrice.toStringAsFixed(0)),
                _DetailChip(label: 'TP', value: decision.takeProfit.toStringAsFixed(0)),
                _DetailChip(label: 'SL', value: decision.stopLoss.toStringAsFixed(0)),
                if (decision.exitPrice != null)
                  _DetailChip(label: 'Exit', value: decision.exitPrice!.toStringAsFixed(0)),
                if (decision.alphaVsBenchmark != null)
                  _DetailChip(label: 'Alpha', value: '${(decision.alphaVsBenchmark! * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});
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

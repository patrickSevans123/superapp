// ─── Trade Plan Detail Screen ────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../../core/router/app_routes.dart';
import '../../data/models/models.dart';
import '../providers/trade_providers.dart';

/// Read-only detail view for a single [TradingPlan].
///
/// The router passes the plan id as a path parameter; we then re-fetch the
/// list and locate the plan by id (the backend has no per-plan endpoint).
class TradePlanDetailScreen extends ConsumerWidget {
  final String planId;

  const TradePlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The API doesn't expose a per-plan fetch, so we re-pull the full list
    // and find by id. For a few hundred plans this is cheap.
    final repo = ref.watch(tradeRepositoryProvider);
    return FutureBuilder<List<TradingPlan>>(
      future: repo.getPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _Scaffold(
            title: 'Loading…',
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _Scaffold(
            title: 'Error',
            child: _buildError(context, snapshot.error.toString(), ref),
          );
        }
        final plans = snapshot.data ?? const <TradingPlan>[];
        TradingPlan? match;
        for (final p in plans) {
          if (p.id == planId) {
            match = p;
            break;
          }
        }
        if (match == null) {
          return _Scaffold(
            title: 'Plan Not Found',
            child: _buildNotFound(context, planId),
          );
        }
        return _PlanDetailContent(plan: match);
      },
    );
  }
}

// ─── Scaffold helper ──────────────────────────────────────────────────────────

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.trade),
        ),
      ),
      body: GradientBackground(child: child),
    );
  }
}

// ─── Not-found & error (top-level so they're callable from the parent) ────────

Widget _buildNotFound(BuildContext context, String planId) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: AppColors.hint),
          const SizedBox(height: 16),
          Text('Plan not found', style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find a trading plan with id "$planId".',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: 'Back to Trade',
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go(AppRoutes.trade),
          ),
        ],
      ),
    ),
  );
}

Widget _buildError(BuildContext context, String error, WidgetRef ref) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Failed to load plan',
            style: AppTextStyles.title.copyWith(
              color: AppColors.stone,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () {
              // Re-trigger the FutureBuilder by pushing the same route again.
              context.go(AppRoutes.trade);
            },
          ),
        ],
      ),
    ),
  );
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _PlanDetailContent extends StatelessWidget {
  const _PlanDetailContent({required this.plan});
  final TradingPlan plan;

  @override
  Widget build(BuildContext context) {
    final change = plan.entryPrice > 0
        ? ((plan.currentPrice ?? plan.entryPrice) - plan.entryPrice) /
                plan.entryPrice *
                100
        : 0.0;
    final isPositive = change >= 0;

    return _Scaffold(
      title: plan.ticker,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isPositive, change),
            const SizedBox(height: 16),
            _buildPriceCard(),
            const SizedBox(height: 16),
            _buildRiskCard(),
            const SizedBox(height: 16),
            _buildDatesCard(),
            if (plan.isClosed) ...[
              const SizedBox(height: 16),
              _buildOutcomeCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isPositive, double change) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withOpacity(0.20)),
            ),
            child: Center(
              child: Text(
                plan.ticker.isNotEmpty ? plan.ticker[0].toUpperCase() : '?',
                style: AppTextStyles.headline.copyWith(
                  fontSize: 22,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.ticker,
                        style: AppTextStyles.headline.copyWith(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      plan.action,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (plan.isActive && plan.pctChange != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPositive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final color = plan.isActive ? AppColors.accent : AppColors.stone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        plan.status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  // ─── Price Card ──────────────────────────────────────────────────────────

  Widget _buildPriceCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Prices', style: AppTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _PriceRow(label: 'Entry', value: _fmt(plan.entryPrice)),
          if (plan.currentPrice != null) ...[
            const SizedBox(height: 8),
            _PriceRow(
              label: 'Current',
              value: _fmt(plan.currentPrice!),
              valueColor: plan.entryPrice > 0 &&
                      plan.currentPrice! >= plan.entryPrice
                  ? AppColors.success
                  : AppColors.error,
            ),
          ],
          if (plan.isClosed && plan.exitPrice != null) ...[
            const SizedBox(height: 8),
            _PriceRow(label: 'Exit', value: _fmt(plan.exitPrice!)),
          ],
          if (plan.pctChange != null) ...[
            const SizedBox(height: 8),
            _PriceRow(
              label: '% Change',
              value: '${plan.pctChange! >= 0 ? '+' : ''}'
                  '${plan.pctChange!.toStringAsFixed(2)}%',
              valueColor: plan.pctChange! >= 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Risk Card (TP / SL) ─────────────────────────────────────────────────

  Widget _buildRiskCard() {
    if (plan.tp == null && plan.sl == null) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Risk Levels',
                  style: AppTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (plan.tp != null)
            _PriceRow(
              label: 'Take Profit (TP)',
              value: _fmt(plan.tp!),
              valueColor: AppColors.success,
            ),
          if (plan.tp != null && plan.sl != null) const SizedBox(height: 8),
          if (plan.sl != null)
            _PriceRow(
              label: 'Stop Loss (SL)',
              value: _fmt(plan.sl!),
              valueColor: AppColors.error,
            ),
        ],
      ),
    );
  }

  // ─── Dates Card ──────────────────────────────────────────────────────────

  Widget _buildDatesCard() {
    final created = _parseDate(plan.createdDate);
    final exited = _parseDate(plan.exitDate ?? '');
    if (created == null && exited == null) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Timeline', style: AppTextStyles.title.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (created != null)
            _PriceRow(label: 'Created', value: created),
          if (created != null && exited != null) const SizedBox(height: 8),
          if (exited != null) _PriceRow(label: 'Closed', value: exited),
        ],
      ),
    );
  }

  // ─── Outcome Card ────────────────────────────────────────────────────────

  Widget _buildOutcomeCard() {
    final isWin = plan.isWin;
    final color = isWin ? AppColors.success : AppColors.error;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWin ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text('Outcome', style: AppTextStyles.title.copyWith(fontSize: 14)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.30)),
                ),
                child: Text(
                  plan.outcome ?? 'CLOSED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (plan.closeReason != null) ...[
            const SizedBox(height: 12),
            Text(
              plan.closeReason!,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.stone,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  String? _parseDate(String d) {
    if (d.isEmpty) return null;
    try {
      return DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}

// ─── Price Row (label + value) ────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.ink,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

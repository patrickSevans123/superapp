import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../data/models/models.dart';
import '../providers/fashion_providers.dart';
import '../widgets/color_swatch_row.dart';

class InsightsDashboardScreen extends ConsumerStatefulWidget {
  const InsightsDashboardScreen({super.key});

  @override
  ConsumerState<InsightsDashboardScreen> createState() =>
      _InsightsDashboardScreenState();
}

class _InsightsDashboardScreenState
    extends ConsumerState<InsightsDashboardScreen> {
  List<ClothingItemModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(fashionApiClientProvider);
      final response = await api.getWardrobe(page: 1, limit: 200);
      if (mounted) {
        setState(() {
          _items = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: 'Analytics'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Could not load insights',
                style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.caption),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Retry',
              onPressed: _loadItems,
              icon: Icons.refresh,
              small: true,
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined,
                size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('Add items to see insights',
                style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return _InsightsContent(items: _items);
  }
}

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({required this.items});
  final List<ClothingItemModel> items;

  @override
  Widget build(BuildContext context) {
    final totalWorn = items.fold<int>(0, (s, i) => s + i.timesWorn);
    final totalCost = items.fold<double>(
        0, (s, i) => s + (i.cost ?? 0));
    final totalInvestment = items.where((i) => i.cost != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OverviewCards(
            itemCount: items.length,
            totalWorn: totalWorn,
            totalCost: totalCost,
          ),
          const SizedBox(height: 14),
          _CategoryBreakdown(items: items),
          const SizedBox(height: 14),
          _InvestmentInsights(
            items: items,
            totalInvestment: totalInvestment,
          ),
          if (_allColors(items).isNotEmpty) ...[
            const SizedBox(height: 14),
            _ColorHarmony(colors: _allColors(items)),
          ],
        ],
      ),
    );
  }

  List<DominantColor> _allColors(List<ClothingItemModel> items) {
    final map = <String, double>{};
    for (final item in items) {
      for (final c in item.dominantColors) {
        map[c.hex] = (map[c.hex] ?? 0) + c.percentage;
      }
    }
    final total = map.values.fold<double>(0, (s, v) => s + v);
    return map.entries
        .map((e) => DominantColor(
            hex: e.key, percentage: (e.value / total * 100)))
        .toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({
    required this.itemCount,
    required this.totalWorn,
    required this.totalCost,
  });

  final int itemCount;
  final int totalWorn;
  final double totalCost;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(value: '$itemCount', label: 'ITEMS')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '$totalWorn', label: 'WORNS')),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: totalCost > 0 ? '\$${totalCost.toStringAsFixed(0)}' : '—',
            label: 'INVESTMENT',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.display.copyWith(fontSize: 26),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.items});
  final List<ClothingItemModel> items;

  @override
  Widget build(BuildContext context) {
    final categoryCount = <String, int>{};
    for (final item in items) {
      categoryCount[item.category] =
          (categoryCount[item.category] ?? 0) + 1;
    }
    final sorted = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassFieldLabel('CATEGORY BREAKDOWN'),
          const SizedBox(height: 14),
          ...sorted.map((e) {
            final pct = (e.value / items.length * 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: AppTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text('${e.value} (${pct.toStringAsFixed(0)}%)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: AppColors.elevated,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InvestmentInsights extends StatelessWidget {
  const _InvestmentInsights({
    required this.items,
    required this.totalInvestment,
  });

  final List<ClothingItemModel> items;
  final int totalInvestment;

  @override
  Widget build(BuildContext context) {
    final withCost = items.where((i) => i.cost != null && i.cost! > 0);

    final bestInvestments = withCost
        .where((i) => i.timesWorn > 0)
        .toList()
      ..sort((a, b) =>
          (a.cost! / a.timesWorn).compareTo(b.cost! / b.timesWorn));

    final hiddenValue = withCost.toList()
      ..sort((a, b) {
        final acpw = a.timesWorn > 0 ? a.cost! / a.timesWorn : double.infinity;
        final bcpw = b.timesWorn > 0 ? b.cost! / b.timesWorn : double.infinity;
        return bcpw.compareTo(acpw);
      });

    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassFieldLabel('INSIGHTS'),
              const Spacer(),
              Text('$totalInvestment items with cost',
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          if (bestInvestments.isNotEmpty) ...[
            Text('Best Investments',
                style: AppTextStyles.title.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            ...bestInvestments.take(3).map((i) => _InsightRow(
                  name: i.name,
                  subtitle:
                      '\$${i.cost!.toStringAsFixed(0)} · ${i.timesWorn}x worn',
                  cpw: i.cost! / i.timesWorn,
                  accent: true,
                )),
          ],
          if (hiddenValue.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Hidden Value',
                style: AppTextStyles.title.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            ...hiddenValue.take(3).map((i) {
              final cpw =
                  i.timesWorn > 0 ? i.cost! / i.timesWorn : double.infinity;
              return _InsightRow(
                name: i.name,
                subtitle: i.timesWorn > 0
                    ? '\$${i.cost!.toStringAsFixed(0)} · ${i.timesWorn}x worn'
                    : 'Unworn · \$${i.cost!.toStringAsFixed(0)}',
                cpw: cpw,
                accent: false,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.name,
    required this.subtitle,
    required this.cpw,
    required this.accent,
  });

  final String name;
  final String subtitle;
  final double cpw;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: accent ? AppColors.success : AppColors.warning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
          Text(
            cpw.isFinite
                ? '\$${cpw.toStringAsFixed(1)}/w'
                : '—',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: accent
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorHarmony extends StatelessWidget {
  const _ColorHarmony({required this.colors});
  final List<DominantColor> colors;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassFieldLabel('WARDROBE COLOR HARMONY'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColorSwatchRow(colors: colors.take(8).toList()),
          ),
        ],
      ),
    );
  }
}

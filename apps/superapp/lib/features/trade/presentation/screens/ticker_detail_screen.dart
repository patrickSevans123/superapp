import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../providers/trade_providers.dart';

/// Detail screen showing technical analysis for a specific ticker.
class TickerDetailScreen extends ConsumerWidget {
  const TickerDetailScreen({super.key, required this.ticker});
  final String ticker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final technicalAsync = ref.watch(technicalProvider(ticker));
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(title: '$ticker Technical Analysis'),
        body: technicalAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Failed to load technical data', style: AppTextStyles.body),
                const SizedBox(height: 12),
                SleekButton(
                  label: 'Retry',
                  variant: SleekButtonVariant.secondary,
                  onPressed: () => ref.invalidate(technicalProvider(ticker)),
                  small: true,
                ),
              ],
            ),
          ),
          data: (data) {
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_outlined, size: 48, color: AppColors.hint),
                    const SizedBox(height: 16),
                    Text('No technical data available', style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Text('Run the daemon to generate technical analysis',
                        style: AppTextStyles.caption),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(technicalProvider(ticker)),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildHeader(context, data),
                  const SizedBox(height: 16),
                  if (data['rsi'] != null) _buildIndicatorCard(context, 'RSI (14)', data['rsi']),
                  if (data['macd'] != null) _buildIndicatorCard(context, 'MACD', data['macd']),
                  if (data['bollinger'] != null) _buildIndicatorCard(context, 'Bollinger Bands', data['bollinger']),
                  if (data['stochastic'] != null) _buildIndicatorCard(context, 'Stochastic', data['stochastic']),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    return GlassBox(
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ticker, style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Technical indicators overview', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(BuildContext context, String title, dynamic indicatorData) {
    if (indicatorData is! Map<String, dynamic>) return const SizedBox.shrink();
    
    // Extract key values from the indicator data
    final entries = indicatorData.entries.where((e) => e.value != null).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${e.key}', style: AppTextStyles.caption),
                Text('${e.value}', style: AppTextStyles.label),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

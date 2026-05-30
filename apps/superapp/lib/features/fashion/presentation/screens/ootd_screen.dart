import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../data/models/models.dart';
import '../providers/fashion_providers.dart';
import '../providers/ootd_notifier.dart';

class OotdScreen extends ConsumerWidget {
  const OotdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ootdAsync = ref.watch(ootdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: "Today's Outfit",
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.stone),
            onPressed: () => ref.invalidate(ootdProvider),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ootdAsync.when(
        loading: () => const _LoadingState(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Something went wrong', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Text(e.toString(), style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(height: 12),
              GlassButton(
                label: 'Retry',
                onPressed: () => ref.invalidate(ootdProvider),
                small: true,
              ),
            ],
          ),
        ),
        data: (suggestion) => _OotdContent(suggestion: suggestion),
      ),
    );
  }
}

class _OotdContent extends ConsumerWidget {
  const _OotdContent({required this.suggestion});
  final OotdSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Weather banner ────────────────────────────────────────────
          _WeatherBanner(weather: suggestion.weather),

          const SizedBox(height: 14),

          if (suggestion.items.isEmpty)
            GlassBox(
              radius: 20,
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.10),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.20)),
                    ),
                    child: const Icon(Icons.checkroom_outlined,
                        color: AppColors.accent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('No suggestions yet',
                      style: AppTextStyles.title,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(
                    'Add more items to your wardrobe to get outfit recommendations.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  _GlassFieldLabel('SUGGESTED OUTFIT'),
                  const Spacer(),
                  Text(
                    '${suggestion.items.length} items',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            ...suggestion.items.map((item) => _OutfitCard(item: item)),
            const SizedBox(height: 20),
            GlassButton(
              label: 'Wear This Outfit Today',
              onPressed: () => _wearAll(context, ref),
              icon: Icons.done_all_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _wearAll(BuildContext context, WidgetRef ref) async {
    // TODO: Integrate with backend when mark-worn endpoint is stable
    for (final item in suggestion.items) {
      try {
        await ref.read(fashionApiClientProvider).markWorn(item.id);
      } catch (_) {
        // Silently fail for now
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Outfit logged!')));
    }
  }
}

// ── Weather banner ────────────────────────────────────────────────────────────

class _WeatherBanner extends StatelessWidget {
  const _WeatherBanner({required this.weather});
  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 16,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weather.city.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppColors.hint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  weather.conditionDescription,
                  style: AppTextStyles.title
                      .copyWith(color: AppColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                _WeatherPill(
                  icon: Icons.water_drop_outlined,
                  label: '${weather.humidity}% humidity',
                ),
                const SizedBox(height: 6),
                _WeatherPill(
                  icon: Icons.thermostat_outlined,
                  label: weather.temperatureBracket.replaceAll('_', ' '),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${weather.temperatureCelsius.round()}°',
                style: AppTextStyles.display
                    .copyWith(fontSize: 56, color: AppColors.ink),
              ),
              Text('C', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherPill extends StatelessWidget {
  const _WeatherPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.hint),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

// ── Outfit card ───────────────────────────────────────────────────────────────

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.item});
  final ClothingItemModel item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.processedImageUrl ?? item.originalImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        radius: 14,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(13)),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.elevated,
                        child: const Icon(Icons.checkroom_outlined,
                            color: AppColors.hint),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: AppTextStyles.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(child: GlassBadge(item.category)),
                          if (item.brand != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item.brand!,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.timesWorn}',
                      style: AppTextStyles.headline.copyWith(fontSize: 18),
                    ),
                    Text('worn', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            3,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline GlassFieldLabel (not exported from shared_ui) ──────────────────────

class _GlassFieldLabel extends StatelessWidget {
  const _GlassFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.label.copyWith(
        color: AppColors.hint,
        letterSpacing: 1.2,
        fontSize: 11,
      ),
    );
  }
}

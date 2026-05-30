import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../utils/color_utils.dart';
import '../../utils/season_utils.dart';
import '../../utils/weather_utils.dart';
import 'fashion_providers.dart';

// ─── OOTD Suggestion Model ──────────────────────────────────────────────────

class OotdSuggestion {
  const OotdSuggestion({
    required this.weather,
    required this.items,
  });

  final WeatherModel weather;
  final List<ClothingItemModel> items;
}

// ─── OOTD Rule Engine (ported from cloth-chooser) ──────────────────────────

class OotdRuleEngine {
  const OotdRuleEngine._();

  static const _slots = ['Tops', 'Bottoms', 'Outerwear', 'Shoes'];
  static const _warmSlots = ['Tops', 'Bottoms', 'Shoes'];
  static const _maxColorRetries = 3;

  static OotdSuggestion suggest(
    WeatherModel weather,
    List<ClothingItemModel> allItems,
  ) {
    final seasonTags = SeasonUtils.currentSeasonTags();
    final bracket = weather.temperatureBracket;

    // Filter by season
    var pool = allItems.where((item) {
      final tags = item.seasonTags;
      return tags.isEmpty || tags.any((t) => seasonTags.contains(t));
    }).toList();

    // Weather-based category filters
    final avoidCategories = <String>{};
    final requireCategories = <String>{};

    if (weather.isRaining) {
      avoidCategories.add('suede');
      requireCategories.add('Outerwear');
    }
    if (bracket == 'very_cold' || bracket == 'cold') {
      requireCategories.add('Outerwear');
    }

    final activeSlots = (bracket == 'warm') ? _warmSlots : _slots;

    final selected = <ClothingItemModel>[];

    for (final slot in activeSlots) {
      final candidates = pool
          .where((item) => item.category == slot)
          .where((item) => !avoidCategories.any(
              (avoidCat) => item.name.toLowerCase().contains(avoidCat)))
          .toList()
        ..sort(_leastWorn);

      if (candidates.isEmpty) continue;

      // Try to find a color-harmonious item
      ClothingItemModel? chosen;
      for (var attempt = 0; attempt < _maxColorRetries; attempt++) {
        final candidate = candidates[min(attempt, candidates.length - 1)];
        if (selected.isEmpty || _isHarmonious(candidate, selected)) {
          chosen = candidate;
          break;
        }
      }
      chosen ??= candidates.first;
      selected.add(chosen);
    }

    return OotdSuggestion(weather: weather, items: selected);
  }

  static int _leastWorn(ClothingItemModel a, ClothingItemModel b) {
    final wornDiff = a.timesWorn.compareTo(b.timesWorn);
    if (wornDiff != 0) return wornDiff;
    if (a.lastWornAt == null && b.lastWornAt == null) return 0;
    if (a.lastWornAt == null) return -1;
    if (b.lastWornAt == null) return 1;
    return a.lastWornAt!.compareTo(b.lastWornAt!);
  }

  static bool _isHarmonious(
      ClothingItemModel candidate, List<ClothingItemModel> existing) {
    if (candidate.dominantColors.isEmpty) return true;
    final candidateHex = candidate.dominantColors.first.hex;
    final candidateColor = ColorUtils.hexToColor(candidateHex);

    for (final item in existing) {
      if (item.dominantColors.isEmpty) continue;
      final existingColor = ColorUtils.hexToColor(item.dominantColors.first.hex);
      if (!ColorUtils.areHarmonious(candidateColor, existingColor)) {
        return false;
      }
    }
    return true;
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────

final weatherDatasourceProvider = Provider<WeatherDatasource>((ref) {
  return WeatherDatasource(Dio());
});

/// Fetches wardrobe items via the API.
final wardrobeItemsProvider = FutureProvider<List<ClothingItemModel>>((ref) async {
  final api = ref.read(fashionApiClientProvider);
  final response = await api.getWardrobe(limit: 200);
  return response.data;
});

/// Provides the OOTD suggestion combining weather and wardrobe data.
///
/// Invalidating this provider will re-fetch weather and wardrobe.
final ootdProvider = FutureProvider<OotdSuggestion>((ref) async {
  final weather = await ref.watch(weatherDatasourceProvider).fetchWeather();
  final wardrobeAsync = ref.watch(wardrobeItemsProvider);
  final items = wardrobeAsync.valueOrNull ?? [];
  return OotdRuleEngine.suggest(weather, items);
});

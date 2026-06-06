import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active mode selection.
const _kActiveSubAppKey = 'active_sub_app';

/// Identifies the three modes of the superapp.
///
/// LPDP used to be a fourth mode but is now accessible as a deep-link
/// destination from the scholarship browse screen (see
/// `browse_screen.dart` → `_buildLpdpEntryCard`).
enum SubApp {
  scholarships('Scholarships', Icons.school, 'scholarship'),
  fashion('Fashion', Icons.checkroom, 'fashion'),
  trade('Trade', Icons.trending_up, 'trade');

  const SubApp(this.label, this.icon, this.routePrefix);
  final String label;
  final IconData icon;
  final String routePrefix;

  /// Description shown next to the mode in the picker.
  String get description {
    switch (this) {
      case SubApp.scholarships:
        return 'Browse & track scholarship opportunities';
      case SubApp.fashion:
        return 'AI-powered wardrobe & style recommendations';
      case SubApp.trade:
        return 'Trading dashboard, signals & portfolio';
    }
  }
}

/// Notifier that tracks which mode is currently active.
///
/// `null` means no mode selected (e.g. first launch before the user picks).
/// The router renders a "pick a mode" prompt in that case; once the user
/// picks a mode from the profile screen the router swaps to that mode's
/// main screen.
class ActiveSubAppNotifier extends StateNotifier<SubApp?> {
  ActiveSubAppNotifier({SubApp? initial}) : super(initial);

  /// Hydrates state from disk. If no value is persisted, defaults to
  /// [SubApp.scholarships] so the app never opens to a blank state.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kActiveSubAppKey);
    if (name != null) {
      final match = SubApp.values.where((s) => s.name == name).firstOrNull;
      if (match != null) {
        state = match;
        return;
      }
    }
    // First launch — default to scholarship so the home tab has content.
    state = SubApp.scholarships;
    await prefs.setString(_kActiveSubAppKey, SubApp.scholarships.name);
  }

  /// Sets the active mode and persists.
  Future<void> setActive(SubApp? app) async {
    state = app;
    final prefs = await SharedPreferences.getInstance();
    if (app != null) {
      await prefs.setString(_kActiveSubAppKey, app.name);
    } else {
      await prefs.remove(_kActiveSubAppKey);
    }
  }
}

/// Provides the currently active mode (null = uninitialised; never null after
/// [ActiveSubAppNotifier.load] has been called).
final activeSubAppProvider =
    StateNotifierProvider<ActiveSubAppNotifier, SubApp?>((ref) {
  return ActiveSubAppNotifier();
});

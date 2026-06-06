import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the user's theme mode preference.
const _kThemeModeKey = 'theme_mode';

/// Notifier that manages the app-wide [ThemeMode] and persists it
/// to [SharedPreferences].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark);

  /// Hydrates state from disk. Call once at app startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kThemeModeKey);
    if (index != null && index < ThemeMode.values.length) {
      state = ThemeMode.values[index];
    }
  }

  /// Persists and applies the given [mode].
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }

  /// Convenience: cycle dark → light → system.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    await setMode(next);
  }
}

/// Provides the app-wide [ThemeMode].
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

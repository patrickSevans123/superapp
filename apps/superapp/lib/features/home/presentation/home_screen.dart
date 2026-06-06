import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sub_app/active_sub_app_provider.dart';
import '../../fashion/presentation/screens/wardrobe_screen.dart';
import '../../scholarship/presentation/screens/browse_screen.dart';
import '../../trade/presentation/screens/trade_dashboard_screen.dart';

/// The "Home" tab content.
///
/// Reads the active mode from [activeSubAppProvider] and renders the
/// corresponding main screen. The mode can be switched from the Profile
/// tab without ever leaving the bottom-nav shell, so this widget
/// transparently swaps content when the user picks a different mode.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeSubAppProvider);
    return switch (mode) {
      SubApp.fashion => const WardrobeScreen(),
      SubApp.trade => const TradeDashboardScreen(),
      // Default + null fall through to scholarship (BrowseScreen is the
      // primary mode of the app and the persisted default on first launch).
      SubApp.scholarships || null => const BrowseScreen(),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../features/scholarship/presentation/screens/browse_screen.dart';
import '../../features/scholarship/presentation/screens/detail_screen.dart';
import '../../features/scholarship/presentation/screens/saved_screen.dart';
import '../../features/fashion/presentation/screens/wardrobe_screen.dart';
import '../../features/fashion/presentation/screens/add_item_screen.dart';
import '../../features/fashion/presentation/screens/insights_dashboard_screen.dart';
import '../../features/fashion/presentation/screens/item_detail_screen.dart';
import '../../features/trade/presentation/screens/trade_dashboard_screen.dart';
import '../../features/trade/presentation/screens/trade_plans_screen.dart';
import '../../features/trade/presentation/screens/trade_news_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/scholarship',
  routes: [
    // ─── Tab Shell (bottom navigation) ───────────────────────────
    ShellRoute(
      builder: (context, state, child) => GlassScaffold(
        body: child,
        bottomNavigationBar: _bottomNav(context, state),
      ),
      routes: [
        GoRoute(
          path: '/scholarship',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: BrowseScreen(),
          ),
        ),
        GoRoute(
          path: '/scholarship/saved',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SavedScreen(),
          ),
        ),
        GoRoute(
          path: '/fashion',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WardrobeScreen(),
          ),
        ),
        GoRoute(
          path: '/trade',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TradeDashboardScreen(),
          ),
          routes: [
            GoRoute(
              path: 'plans',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TradePlansScreen(),
              ),
            ),
            GoRoute(
              path: 'news',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TradeNewsScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: EditProfileScreen(),
              ),
            ),
            GoRoute(
              path: 'settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'notifications',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: NotificationPreferencesScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ─── Detail routes (outside ShellRoute so bottom nav is hidden) ──
    GoRoute(
      path: '/scholarship/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage(
          key: ValueKey(id),
          child: DetailScreen(id: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
    GoRoute(
      path: '/fashion/add',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: AddItemScreen(),
      ),
    ),
    GoRoute(
      path: '/fashion/insights',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: InsightsDashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/fashion/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage(
          key: ValueKey(id),
          child: ItemDetailScreen(itemId: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
  ],
);

NavigationBar _bottomNav(BuildContext context, GoRouterState state) {
  final location = state.uri.path;
  return NavigationBar(
    selectedIndex: _navIndex(location),
    onDestinationSelected: (i) => context.go(_navPaths[i]),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.school), label: 'Scholarship'),
      NavigationDestination(icon: Icon(Icons.checkroom), label: 'Fashion'),
      NavigationDestination(icon: Icon(Icons.trending_up), label: 'Trade'),
      NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
    ],
  );
}

int _navIndex(String path) {
  if (path.startsWith('/scholarship')) return 0;
  if (path.startsWith('/fashion')) return 1;
  if (path.startsWith('/trade')) return 2;
  return 3;
}

const _navPaths = ['/scholarship', '/fashion', '/trade', '/profile'];



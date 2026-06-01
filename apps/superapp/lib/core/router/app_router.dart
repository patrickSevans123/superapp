import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../features/lpdp/presentation/screens/lpdp_dashboard_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_university_list_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_university_detail_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_bidang_screen.dart';
import '../../features/scholarship/presentation/screens/browse_screen.dart';
import '../../features/scholarship/presentation/screens/detail_screen.dart';
import '../../features/scholarship/presentation/screens/saved_screen.dart';
import '../../features/scholarship/presentation/screens/stats_dashboard_screen.dart';
import '../../features/fashion/presentation/screens/wardrobe_screen.dart';
import '../../features/fashion/presentation/screens/add_item_screen.dart';
import '../../features/fashion/presentation/screens/insights_dashboard_screen.dart';
import '../../features/fashion/presentation/screens/item_detail_screen.dart';
import '../../features/trade/presentation/screens/trade_dashboard_screen.dart';
import '../../features/trade/presentation/screens/trade_plans_screen.dart';
import '../../features/trade/presentation/screens/trade_news_screen.dart';
import '../../features/trade/presentation/screens/trade_plan_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import 'app_routes.dart';

/// 200ms fade transition used for detail routes so the bottom nav hides
/// smoothly and the new screen fades in (better than the default slide on
/// web/desktop and avoids a janky shell+detail overlay on mobile).
CustomTransitionPage<T> _fadePage<T>(LocalKey key, Widget child) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

/// The post-login router (the auth-router is defined in `app.dart`).
///
/// All route paths come from [AppRoutes] so refactors stay in one place.
final appRouter = GoRouter(
  initialLocation: AppRoutes.scholarship,
  debugLogDiagnostics: false,
  errorBuilder: (context, state) => _NotFoundScreen(
    attemptedPath: state.uri.path,
  ),
  routes: [
    // ─── Tab Shell (bottom navigation) ───────────────────────────────
    ShellRoute(
      builder: (context, state, child) => GlassScaffold(
        body: child,
        bottomNavigationBar: _bottomNav(context, state),
      ),
      routes: [
        GoRoute(
          path: AppRoutes.scholarship,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: BrowseScreen()),
          routes: [
            GoRoute(
              path: 'stats',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: StatsDashboardScreen()),
            ),
            GoRoute(
              path: 'saved',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: SavedScreen()),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.fashion,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: WardrobeScreen()),
        ),
        GoRoute(
          path: AppRoutes.trade,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: TradeDashboardScreen()),
          routes: [
            GoRoute(
              path: 'plans',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: TradePlansScreen()),
            ),
            GoRoute(
              path: 'news',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: TradeNewsScreen()),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: ProfileScreen()),
          routes: [
            GoRoute(
              path: 'edit',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: EditProfileScreen()),
            ),
            GoRoute(
              path: 'settings',
              pageBuilder: (_, __) =>
                  const NoTransitionPage(child: SettingsScreen()),
              routes: [
                GoRoute(
                  path: 'notifications',
                  pageBuilder: (_, __) => const NoTransitionPage(
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
      path: AppRoutes.scholarshipDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(ValueKey('sch_${id}_${state.uri.query}'),
            DetailScreen(id: id));
      },
    ),
    GoRoute(
      path: AppRoutes.tradePlanDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(
          ValueKey('trade_plan_$id'),
          TradePlanDetailScreen(planId: id),
        );
      },
    ),

    // ─── LPDP Routes (nested under /lpdp) ────────────────────────────
    GoRoute(
      path: AppRoutes.lpdp,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: LpdpDashboardScreen()),
      routes: [
        GoRoute(
          path: 'universities',
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: LpdpUniversityListScreen()),
        ),
        GoRoute(
          path: 'university/:name',
          pageBuilder: (context, state) {
            final name = state.pathParameters['name']!;
            return _fadePage(ValueKey('lpdp_univ_$name'),
                LpdpUniversityDetailScreen(name: name));
          },
        ),
        GoRoute(
          path: 'bidang/:bidang',
          pageBuilder: (context, state) {
            final bidang = state.pathParameters['bidang']!;
            return _fadePage(ValueKey('lpdp_bidang_$bidang'),
                LpdpBidangScreen(bidang: bidang));
          },
        ),
      ],
    ),

    // ─── Fashion Routes ──────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.fashionAdd,
      pageBuilder: (_, __) => const NoTransitionPage(child: AddItemScreen()),
    ),
    GoRoute(
      path: AppRoutes.fashionInsights,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: InsightsDashboardScreen()),
    ),
    GoRoute(
      path: AppRoutes.fashionDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(ValueKey(id), ItemDetailScreen(itemId: id));
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
  if (path.startsWith(AppRoutes.scholarship)) return 0;
  if (path.startsWith(AppRoutes.fashion)) return 1;
  if (path.startsWith(AppRoutes.trade)) return 2;
  return 3;
}

const _navPaths = [
  AppRoutes.scholarship,
  AppRoutes.fashion,
  AppRoutes.trade,
  AppRoutes.profile,
];

/// Fallback screen for unmatched routes (deep links to dead URLs etc.).
class _NotFoundScreen extends StatelessWidget {
  final String attemptedPath;
  const _NotFoundScreen({required this.attemptedPath});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(title: 'Not Found'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 64, color: AppColors.hint),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 8),
                Text(
                  attemptedPath,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SleekButton.gradient(
                  label: 'Go home',
                  onPressed: () => context.go(AppRoutes.scholarship),
                  icon: Icons.home,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../auth/auth_state.dart';
import '../../features/fashion/presentation/screens/add_item_screen.dart';
import '../../features/fashion/presentation/screens/insights_dashboard_screen.dart';
import '../../features/fashion/presentation/screens/item_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_bidang_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_dashboard_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_university_detail_screen.dart';
import '../../features/lpdp/presentation/screens/lpdp_university_list_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/scholarship/presentation/screens/detail_screen.dart';
import '../../features/scholarship/presentation/screens/saved_screen.dart';
import '../../features/scholarship/presentation/screens/stats_dashboard_screen.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/trade/presentation/screens/daily_reports_screen.dart';
import '../../features/trade/presentation/screens/decision_journal_screen.dart';
import '../../features/trade/presentation/screens/factor_lab_screen.dart';
import '../../features/trade/presentation/screens/portfolio_optimize_screen.dart';
import '../../features/trade/presentation/screens/regime_screen.dart';
import '../../features/trade/presentation/screens/research_report_detail_screen.dart';
import '../../features/trade/presentation/screens/research_reports_screen.dart';
import '../../features/trade/presentation/screens/signals_screen.dart';
import '../../features/trade/presentation/screens/ticker_detail_screen.dart';
import '../../features/trade/presentation/screens/trade_news_screen.dart';
import '../../features/trade/presentation/screens/trade_plan_detail_screen.dart';
import '../../features/trade/presentation/screens/trade_plans_screen.dart';
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
///
/// ## Architecture
///
/// The bottom navigation is intentionally **minimal** — just two
/// destinations: `Home` and `Profile`.
///
/// * `Home` is a smart widget ([HomeScreen]) that reads the active mode
///   from `activeSubAppProvider` and renders the matching main screen
///   (Browse / Wardrobe / Trade Dashboard). Switching modes from
///   `Profile` instantly swaps the home content without a router rebuild.
/// * `Profile` exposes the mode switcher (in a hidden-but-discoverable
///   tile), so the bottom bar is **not** polluted with Scholarship /
///   Fashion / Trade tabs.
///
/// All sub-routes (`/scholarship/*`, `/fashion/*`, `/trade/*`,
/// `/lpdp/*`) are mounted **outside** the shell so the bottom nav
/// disappears on detail screens — standard mobile pattern.
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: false,
  refreshListenable: authRefreshListenable,
  redirect: (context, state) {
    // The post-login router should only show post-login routes. If
    // the user has been logged out (e.g. token expired), kick to
    // `/login` so the auth flow takes over.
    if (!authRefreshListenable.value) {
      return AppRoutes.login;
    }
    // When `routerConfig` switches from `authRouter` to `appRouter`
    // after login/register, the browser URL may still be `/login` or
    // `/register`. These routes don't exist in the post-login router,
    // so redirect to home to avoid a "Page not found" error.
    if (state.uri.path == AppRoutes.login ||
        state.uri.path == AppRoutes.register) {
      return AppRoutes.home;
    }
    return null;
  },
  errorBuilder: (context, state) => _NotFoundScreen(
    attemptedPath: state.uri.path,
  ),
  routes: [
    // ─── Tab Shell (Home + Profile) ───────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => GlassScaffold(
        body: child,
        bottomNavigationBar: _bottomNav(context, state),
      ),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: HomeScreen()),
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

    // ─── Scholarship sub-routes (outside shell) ──────────────────────
    GoRoute(
      path: AppRoutes.scholarshipStats,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: StatsDashboardScreen()),
    ),
    GoRoute(
      path: AppRoutes.scholarshipSaved,
      pageBuilder: (_, __) => const NoTransitionPage(child: SavedScreen()),
    ),
    GoRoute(
      path: AppRoutes.scholarshipDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(ValueKey('sch_${id}_${state.uri.query}'),
            DetailScreen(id: id));
      },
    ),

    // ─── Trade sub-routes (outside shell) ────────────────────────────
    GoRoute(
      path: AppRoutes.tradePlans,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: TradePlansScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeNews,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: TradeNewsScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeReports,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: DailyReportsScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeResearch,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: ResearchReportsListScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeSignals,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: SignalsScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeRegime,
      pageBuilder: (_, __) => const NoTransitionPage(child: RegimeScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeDecisions,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: DecisionJournalScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradeFactorLab,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: FactorLabScreen()),
    ),
    GoRoute(
      path: AppRoutes.tradePortfolioOptimize,
      pageBuilder: (_, __) =>
          const NoTransitionPage(child: PortfolioOptimizeScreen()),
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
    GoRoute(
      path: AppRoutes.tradeResearchDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _fadePage(
          ValueKey('trade_research_$id'),
          ResearchReportDetailScreen(reportId: id),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.tradeTickerDetail,
      pageBuilder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return _fadePage(
          ValueKey('trade_ticker_$symbol'),
          TickerDetailScreen(ticker: symbol),
        );
      },
    ),

    // ─── Fashion sub-routes (outside shell) ───────────────────────────
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

    // ─── LPDP deep-link routes (entry point lives in BrowseScreen) ────
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

    // ─── Legacy sub-app deep-links ────────────────────────────────────
    // Some screens still emit `context.go('/scholarship')` or
    // `context.go('/trade')` from inside detail flows. We redirect those
    // to `/home` so the user lands on the active mode's main screen
    // rather than getting a "Page not found" flash. The active mode is
    // already tracked by `activeSubAppProvider`; the user can change it
    // from the Profile tab.
    GoRoute(
      path: '/scholarship',
      redirect: (_, __) => AppRoutes.home,
    ),
    GoRoute(
      path: '/fashion',
      redirect: (_, __) => AppRoutes.home,
    ),
    GoRoute(
      path: '/trade',
      redirect: (_, __) => AppRoutes.home,
    ),
  ],
);

/// Two-tab bottom nav: Home (active mode's main screen) and Profile.
NavigationBar _bottomNav(BuildContext context, GoRouterState state) {
  final location = state.uri.path;
  final selectedIndex = location.startsWith(AppRoutes.profile) ? 1 : 0;
  return NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (i) => context.go(i == 0 ? AppRoutes.home : AppRoutes.profile),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
}

/// Fallback screen for unmatched routes (deep links to dead URLs etc.).
class _NotFoundScreen extends StatelessWidget {
  final String attemptedPath;
  const _NotFoundScreen({required this.attemptedPath});

  @override
  Widget build(BuildContext context) {
    return AuroraMeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const GlassAppBar(title: 'Not Found'),
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
                GlassButton(
                  label: 'Go home',
                  onPressed: () => context.go(AppRoutes.home),
                  icon: Icons.home,
                  small: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

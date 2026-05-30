import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../features/scholarship/presentation/screens/browse_screen.dart';
import '../../features/scholarship/presentation/screens/detail_screen.dart';

// ─── Placeholder screens (will be replaced with real features) ───

Widget _placeholder(String label) => GradientBackground(
      child: Center(child: GlassBadge(label, accent: true)),
    );

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
          path: '/fashion',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _FashionPlaceholder(),
          ),
        ),
        GoRoute(
          path: '/trade',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _TradePlaceholder(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _ProfilePlaceholder(),
          ),
        ),
      ],
    ),

    // ─── Detail route (outside ShellRoute so bottom nav is hidden) ──
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

// ─── Placeholder widgets ───

class _FashionPlaceholder extends StatelessWidget {
  const _FashionPlaceholder();
  @override
  Widget build(BuildContext context) => _placeholder('FASHION');
}

class _TradePlaceholder extends StatelessWidget {
  const _TradePlaceholder();
  @override
  Widget build(BuildContext context) => _placeholder('TRADE');
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) => _placeholder('PROFILE');
}

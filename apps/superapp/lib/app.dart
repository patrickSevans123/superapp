import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/widgets/global_app_banner.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';

/// Auth-only router used when the user is not logged in.
final authRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
  ],
);

class Superapp extends ConsumerWidget {
  const Superapp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp.router(
      title: 'Superapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: authState.isLoggedIn ? appRouter : authRouter,
      // Wraps the navigator with the global in-app banner overlay so
      // notifications can pop above any screen (auth or main shell).
      builder: (context, child) =>
          GlobalAppBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}

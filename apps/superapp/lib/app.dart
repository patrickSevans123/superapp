import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import 'core/auth/auth_state.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/widgets/global_app_banner.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'l10n/generated/app_localizations.dart';

/// Auth-only router used when the user is not logged in.
///
/// `refreshListenable` + `redirect` together handle the case where a
/// user is already logged in but lands on `/login` (e.g. by typing
/// it in the URL bar, or hitting back after login). They're bounced
/// to `/scholarship` automatically.
final authRouter = GoRouter(
  initialLocation: AppRoutes.login,
  refreshListenable: authRefreshListenable,
  redirect: (context, state) {
    if (authRefreshListenable.value) {
      // Already logged in — kick to the post-login home.
      return AppRoutes.scholarship;
    }
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(
        path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
  ],
);

class Superapp extends ConsumerWidget {
  const Superapp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-runs the build on every auth state flip, which remounts
    // the router. Combined with `redirect` + `refreshListenable` on
    // both routers (see `appRouter` and `authRouter`), this removes
    // the race window where a stale router is still on screen for
    // one frame after login/logout.
    ref.watch(authStateProvider);

    return MaterialApp.router(
      title: 'Superapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Localisation: EN + ID. The .arb files live in `lib/l10n/`
      // and the generated `AppLocalizations` is in `lib/l10n/generated/`
      // (run `flutter pub get` + `flutter gen-l10n`).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: authRefreshListenable.value ? appRouter : authRouter,
      // Wraps the navigator with the global in-app banner overlay so
      // notifications can pop above any screen (auth or main shell).
      builder: (context, child) =>
          GlobalAppBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}

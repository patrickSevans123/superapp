import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import 'core/auth/auth_state.dart';
import 'core/pin/pin_provider.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/sub_app/active_sub_app_provider.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/update/update_dialog.dart';
import 'core/update/update_provider.dart';
import 'core/widgets/global_app_banner.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/pin/presentation/screens/pin_input_screen.dart';
import 'l10n/generated/app_localizations.dart';

/// Auth-only router used when the user is not logged in.
///
/// Does **not** use [authRefreshListenable] as its `refreshListenable`
/// because the [MaterialApp.router] already switches between [authRouter]
/// and the post-login [appRouter] via `routerConfig`. Adding a
/// `refreshListenable` here would fire a redirect to `/home`
/// (which is not in this router's route table) before the
/// `routerConfig` switch takes effect, causing a "Page not found" error.
final authRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(
        path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
  ],
);

class Superapp extends ConsumerStatefulWidget {
  const Superapp({super.key});

  @override
  ConsumerState<Superapp> createState() => _SuperappState();
}

class _SuperappState extends ConsumerState<Superapp> {
  bool _updateCheckScheduled = false;
  bool _initialized = false;
  bool _pinVerified = false;

  @override
  void initState() {
    super.initState();
    // Hydrate persisted state on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        ref.read(themeModeProvider.notifier).load();
        ref.read(activeSubAppProvider.notifier).load();
        _checkPin();
      }
    });
  }

  Future<void> _checkPin() async {
    try {
      final enabled = await ref.read(pinServiceProvider).isPinEnabled();
      if (enabled && mounted && !_pinVerified) {
        // Show PIN input as a full-screen modal.
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const PinInputScreen(),
          ),
        );
        if (mounted) {
          setState(() => _pinVerified = result == true);
        }
      } else {
        setState(() => _pinVerified = true);
      }
    } catch (e) {
      // If PIN check fails (e.g. secure_storage unavailable on web),
      // unblock the app so it can still render the login screen.
      debugPrint('PIN check failed: $e');
      if (mounted) {
        setState(() => _pinVerified = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-run on auth state flip.
    ref.watch(authStateProvider);

    // Watch theme mode.
    final themeMode = ref.watch(themeModeProvider);

    // Listen for update availability and show dialog once.
    if (!_updateCheckScheduled) {
      _updateCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleUpdateCheck();
      });
    }

    // Block on PIN verification — show blank screen until verified.
    if (!_pinVerified) {
      // Use onGenerateRoute so any browser URL (e.g. /register from a
      // prior session) resolves to the loading screen without triggering
      // a "Could not navigate to initial route" error.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const Scaffold(
            backgroundColor: Color(0xFF09090B),
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Superapp',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: authRefreshListenable.value ? appRouter : authRouter,
      builder: (context, child) =>
          GlobalAppBanner(child: child ?? const SizedBox.shrink()),
    );
  }

  void _scheduleUpdateCheck() {
    if (kIsWeb || kDebugMode) return;

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      try {
        final notifier = ref.read(updateProvider.notifier);
        await notifier.checkForUpdate();
        if (!mounted) return;

        final state = ref.read(updateProvider);
        if (state.status == UpdateStatus.available &&
            state.latestVersion != null) {
          showUpdateDialog(
            context,
            forceUpdate: state.latestVersion!.forceUpdate,
          );
        }
      } catch (e) {
        debugPrint('Startup update check failed: $e');
      }
    });
  }
}

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/auth/auth_state.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

void main() async {
  // Catch all uncaught Flutter framework errors.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught FlutterError: ${details.exception}\n${details.stack}');
  };

  // Catch all uncaught async errors that escape the Flutter framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error\n$stack');
    return true;
  };

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();

    // Initialize Firebase (required for FCM on Android/iOS)
    await Firebase.initializeApp();

    // Pre-load SharedPreferences so the `has_secure_token` boolean hint
    // is read synchronously on cold start (no microtask gap). The
    // actual JWT lives in flutter_secure_storage and is loaded
    // asynchronously by [AuthNotifier.loadToken] after the first frame.
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        coreAuthNotifierProvider.overrideWith(createCoreAuthNotifier),
      ],
    );

    runApp(UncontrolledProviderScope(
      container: container,
      child: const Superapp(),
    ));

    // After the first frame, hydrate the JWT from secure storage and
    // (if applicable) schedule a proactive logout at the token's
    // expiry time. We can't read from secure storage on the first
    // frame synchronously — the plugin is async.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = container.read(authStateProvider.notifier);
      await notifier.loadToken();
      notifier.scheduleExpiryLogout();

      // Initialize push notifications after auth is loaded
      final notificationService = container.read(notificationServiceProvider);
      final authState = container.read(authStateProvider);
      final userId = authState.user?.id;
      await notificationService.initialize(userId: userId);
    });
  }, (error, stack) {
    debugPrint('Uncaught zoned error: $error\n$stack');
  });
}

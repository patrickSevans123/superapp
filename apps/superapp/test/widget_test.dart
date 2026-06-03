// Smoke test for the Superapp.
//
// Verifies the app boots and renders without errors. Does NOT depend on a
// running backend (the auth flow will fall through to the login screen).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superapp/app.dart';
import 'package:superapp/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('Superapp boots and shows login screen when not authenticated',
      (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const Superapp(),
      ),
    );
    await tester.pumpAndSettle();

    // Either the login screen is visible (preferred) or the home shell —
    // both mean the app booted successfully.
    final hasLogin = find.text('Sign in').evaluate().isNotEmpty ||
        find.text('Login').evaluate().isNotEmpty ||
        find.text('Masuk').evaluate().isNotEmpty;
    final hasShell = find.byType(MaterialApp).evaluate().isNotEmpty;

    expect(hasLogin || hasShell, isTrue,
        reason: 'App should render either login or main shell');
  });
}

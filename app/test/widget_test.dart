// 2026-08-29: this used to be the untouched `flutter create` counter-app
// template test — it asserted a "0"/"1" counter and a '+' FAB that this app
// never had (MyApp has always been the real FMS app, never the demo
// counter), so it failed unconditionally and told nobody anything useful.
// Replaced with a minimal real smoke test: the app must at least build and
// render its MaterialApp without throwing. Deliberately a single pump()
// rather than pumpAndSettle() — SplashPage kicks off a real network call
// (session check) in initState(), and pumpAndSettle() would sit there
// waiting for that timer/timeout to resolve, making the test slow or flaky
// with no network available in CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App builds and renders without throwing', (WidgetTester tester) async {
    // SplashPage reads SharedPreferences on initState() — without this,
    // the plugin has no mock platform channel registered in a pure widget
    // test and would throw before the widget tree even settles.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

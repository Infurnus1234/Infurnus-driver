import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/main.dart';
import 'package:infurnus_driver/providers/app_state.dart';
import 'package:infurnus_driver/providers/driver_session.dart';

void main() {
  testWidgets(
    'Unauthenticated startup requires login instead of demo dashboard',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppState()),
            ChangeNotifierProvider(create: (_) => DriverSession()),
          ],
          child: const InfurnusApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log in or sign up'), findsOneWidget);
      expect(find.text('Driver Dashboard'), findsNothing);
    },
  );

  testWidgets('LoginScreen does not expose debug preview dashboard button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => DriverSession()),
        ],
        child: const InfurnusApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Preview Dashboard (Testing Only)'),
      findsNothing,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Enter Phone Number'), findsOneWidget);
  });

  test('Production state contains no seeded user, rides or financial data', () {
    final state = AppState();
    expect(state.isLoggedIn, isFalse);
    expect(state.currentUser, isNull);
    expect(state.bookings, isEmpty);
    expect(state.walletBalance, 0);
    expect(state.vehicles, isEmpty);
    state.dispose();
  });
}

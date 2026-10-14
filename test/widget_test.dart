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
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Driver Dashboard'), findsNothing);
    },
  );

  testWidgets(
    'Debug preview button is visible on LoginScreen and opens dashboard with test banner',
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
      expect(find.text('Preview Dashboard (Testing Only)'), findsOneWidget);

      await tester.tap(find.text('Preview Dashboard (Testing Only)'));
      await tester.pumpAndSettle();

      expect(find.text('TEST PREVIEW — NOT AUTHENTICATED'), findsOneWidget);
    },
  );

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

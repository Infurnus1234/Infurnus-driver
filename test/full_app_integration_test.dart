import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/app_state.dart';
import 'package:infurnus_driver/screens/auth/welcome_screen.dart';
import 'package:infurnus_driver/screens/driver/my_trips_screen.dart';
import 'package:infurnus_driver/screens/driver/wallet_screen.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  testWidgets('INFURNUS Full App Screens Render Successfully', (
    WidgetTester tester,
  ) async {
    // Test Welcome Screen
    await tester.pumpWidget(
      MaterialApp(theme: InfurnusTheme.lightTheme, home: const WelcomeScreen()),
    );
    expect(find.text('Drive.\nEarn.\nGrow Together.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Test My Trips Screen with AppState provider
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: const MyTripsScreen(),
        ),
      ),
    );
    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed').first, findsOneWidget);

    // Test Driver Wallet Screen with AppState provider
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: const WalletScreen(),
        ),
      ),
    );
    expect(find.text('Driver Wallet'), findsOneWidget);
    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('Withdraw Payout'), findsOneWidget);
  });
}

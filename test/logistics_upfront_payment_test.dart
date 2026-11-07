import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/driver/driver_navigation_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Logistics booking blocks start ride when upfront payment is pending',
    (tester) async {
      final session = DriverSession();
      session.isPreview = true;
      session.currentTrip = {
        'id': 'logistics-trip-1',
        'sector': 'logistics',
        'status': 'driver_arrived',
        'upfrontPaymentStatus': 'PENDING',
        'upfrontPaymentMethod': 'online',
        'finalFare': 10000,
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: DriverNavigationScreen()),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Logistics 40% Upfront Payment'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Logistics 40% Upfront Payment'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      final success = await session.transition('in_progress');
      expect(success, isFalse);
    },
  );

  testWidgets(
    'Logistics booking allows start ride after online upfront payment verification',
    (tester) async {
      final session = DriverSession();
      session.isPreview = true;
      session.currentTrip = {
        'id': 'logistics-trip-1',
        'sector': 'logistics',
        'status': 'driver_arrived',
        'upfrontPaymentStatus': 'PENDING',
        'upfrontPaymentMethod': 'online',
        'finalFare': 10000,
        'pinVerified': true,
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: DriverNavigationScreen()),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Logistics 40% Upfront Payment'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      // Simulate paying online
      await session.payLogisticsUpfrontOnline('logistics-trip-1');
      await tester.pump();

      expect(session.currentTrip?['upfrontPaymentStatus'], 'PAID_VERIFIED');
      expect(find.text('Paid Verified'), findsOneWidget);

      // Now transition should succeed in preview mode
      final success = await session.transition('in_progress');
      expect(success, isTrue);
      expect(session.currentTrip?['status'], 'in_progress');
    },
  );

  testWidgets('Logistics cash upfront confirmation sets PAID_VERIFIED', (
    tester,
  ) async {
    final session = DriverSession();
    session.isPreview = true;
    session.currentTrip = {
      'id': 'logistics-trip-2',
      'sector': 'logistics',
      'status': 'driver_arrived',
      'upfrontPaymentStatus': 'PENDING',
      'upfrontPaymentMethod': 'cash',
      'finalFare': 5000,
    };

    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: const MaterialApp(home: DriverNavigationScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Confirm 40% Cash Received'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Confirm 40% Cash Received'), findsOneWidget);
    await session.confirmLogisticsUpfrontCash('logistics-trip-2');
    await tester.pump();

    expect(session.currentTrip?['upfrontPaymentStatus'], 'PAID_VERIFIED');
  });

  testWidgets(
    'Regular passenger ride ignores logistics upfront payment check',
    (tester) async {
      final session = DriverSession();
      session.isPreview = true;
      session.currentTrip = {
        'id': 'passenger-trip-1',
        'sector': 'passenger',
        'status': 'driver_arrived',
        'fareEstimate': 300,
      };

      final success = await session.transition('in_progress');
      expect(success, isTrue);
      expect(session.currentTrip?['status'], 'in_progress');
    },
  );
}

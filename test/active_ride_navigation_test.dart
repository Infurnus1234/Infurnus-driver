import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/screens/driver/driver_navigation_screen.dart';
import 'package:infurnus_driver/widgets/trip_map.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('ride details have three heights and can scroll at half height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSession()..currentTrip = _trip();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: DriverNavigationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('active-ride-panel'));
    final handle = find.byKey(const ValueKey('ride-details-handle'));
    final map = find.byType(TripMap);
    final originalMap = tester.state(map);
    expect(tester.getSize(panel).height, closeTo(740 * .18, 1));
    expect(tester.getSize(map), const Size(360, 740));
    expect(find.text('Booking #4441604 · In progress'), findsOneWidget);
    expect(find.text('Complete Ride').hitTestable(), findsNothing);

    await tester.drag(handle, const Offset(0, -205));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, closeTo(370, 1));
    expect(tester.widget<TripMap>(map).bottomInset, closeTo(370, 1));
    final details = find
        .descendant(of: panel, matching: find.byType(Scrollable))
        .first;
    await tester.drag(details, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, closeTo(370, 1));
    expect(
      tester.state<ScrollableState>(details).position.pixels,
      greaterThan(0),
    );

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, closeTo(740 * .86, 1));
    expect(find.text('Support').hitTestable(), findsOneWidget);
    expect(tester.state(map), same(originalMap));

    await tester.tapAt(const Offset(8, 86));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, closeTo(740 * .18, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('system Back and the ongoing card reopen the same ride', (
    tester,
  ) async {
    final session = _DelayedCompletionSession()
      ..isPreview = true
      ..currentTrip = _trip();
    final router = createAppRouter();
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/driver/active-trip');
    await tester.pumpAndSettle();
    final ride = session.currentTrip;
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Ongoing ride · Booking #4441604'), findsOneWidget);
      expect(session.currentTrip, same(ride));
      await tester.tap(find.text('Return to your active ride'));
      await tester.pumpAndSettle();
      expect(find.byType(DriverNavigationScreen), findsOneWidget);
      expect(session.currentTrip?['status'], 'in_progress');
    }
    final handle = find.byKey(const ValueKey('ride-details-handle'));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    await tester.tap(handle);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete Ride'));
    await tester.tap(find.text('Complete Ride'));
    await tester.pumpAndSettle();
    if (find.text('Delivery PIN').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Verify & Complete'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/driver/dashboard');
    expect(find.text('Return to your active ride'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    session.dispose();
  });
}

class _DelayedCompletionSession extends DriverSession {
  @override
  Future<bool> transition(String status, {String? pin, String? endPin}) async {
    final result = await super.transition(status, pin: pin, endPin: endPin);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return result;
  }
}

Map<String, dynamic> _trip() => {
  'id': 'qa-ride',
  'bookingId': '4441604',
  'status': 'in_progress',
  'sector': 'logistics',
  'pickupAddress': 'Patna',
  'destinationAddress': 'Muzaffarpur',
  'pinVerified': true,
  'fareEstimate': 2003,
  'upfrontPaymentStatus': 'PAID_VERIFIED',
};

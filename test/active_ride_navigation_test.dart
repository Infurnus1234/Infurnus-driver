import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/screens/driver/driver_navigation_screen.dart';
import 'package:infurnus_driver/widgets/trip_map.dart';
import 'package:provider/provider.dart';

void main() {
  for (final sector in ['logistics', 'premium', 'rental', 'service']) {
    testWidgets('$sector completion requires two accurate destination fixes', (
      tester,
    ) async {
      final (latitude, longitude) = sector == 'logistics'
          ? (26.65, 84.92) // Motihari
          : (25.86, 85.78); // Samastipur
      final session = _LocationSession()
        ..currentTrip = {
          ..._trip(),
          'sector': sector,
          'destination': {'latitude': latitude, 'longitude': longitude},
        };
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: DriverNavigationScreen()),
        ),
      );
      final button = find.text('Complete Ride');
      expect(button, findsNothing);
      final stale = DateTime.now().subtract(const Duration(minutes: 1));
      session.sample(_fix(latitude, longitude, stale));
      session.sample(
        _fix(latitude, longitude, stale.add(const Duration(seconds: 1))),
      );
      await tester.pump();
      expect(button, findsNothing);
      var timestamp = DateTime.now().subtract(const Duration(seconds: 15));
      session.sample(_fix(25.61, 85.14, timestamp)); // Patna
      await tester.pump();
      expect(button, findsNothing);
      Future<void> fix(double offset, {double accuracy = 8}) async {
        timestamp = timestamp.add(const Duration(milliseconds: 500));
        session.sample(
          _fix(
            latitude + offset / 111195,
            longitude,
            timestamp,
            accuracy: accuracy,
          ),
        );
        await tester.pump();
      }

      for (final distance in [10000.0, 1000.0, 200.0]) {
        await fix(distance);
        await fix(distance);
        expect(button, findsNothing);
      }
      await fix(80);
      expect(button, findsNothing);
      await fix(80, accuracy: 35);
      expect(button, findsNothing);
      await fix(80);
      expect(button, findsNothing);
      await fix(80);
      expect(button, findsOneWidget);
      await fix(200);
      expect(button, findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }

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
    final now = DateTime.now();
    session.position = _fix(
      26.12,
      85.39,
      now.subtract(const Duration(seconds: 2)),
    );
    session.position = _fix(26.12, 85.39, now);
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
  Future<bool> transition(String status, {String? pin}) async {
    final result = await super.transition(status, pin: pin);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return result;
  }
}

class _LocationSession extends DriverSession {
  void sample(Position fix) {
    position = fix;
    notifyListeners();
  }
}

Position _fix(
  double latitude,
  double longitude,
  DateTime timestamp, {
  double accuracy = 8,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp,
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Map<String, dynamic> _trip() => {
  'id': 'qa-ride',
  'bookingId': '4441604',
  'status': 'in_progress',
  'sector': 'logistics',
  'pickupAddress': 'Patna',
  'destinationAddress': 'Muzaffarpur',
  'destination': {'latitude': 26.12, 'longitude': 85.39},
  'pinVerified': true,
  'fareEstimate': 2003,
  'upfrontPaymentStatus': 'PAID_VERIFIED',
};

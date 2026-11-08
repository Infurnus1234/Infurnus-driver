import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/driver/driver_navigation_screen.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:provider/provider.dart';

const _rideId = 'test-ride';

class _Session extends DriverSession {
  _Session(ApiService api) : super(api: api);

  @override
  bool get authenticated => api.accessToken != null;

  void gpsTick() {
    position = Position(
      longitude: 85.14,
      latitude: 25.60,
      timestamp: DateTime.now(),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    notifyListeners();
  }
}

Map<String, dynamic> _ride({bool paid = false, bool includeBooking = true}) => {
  'id': _rideId,
  'status': 'driver_arrived',
  'sector': 'logistics',
  if (includeBooking) 'bookingId': '4441604',
  'pickupAddress': 'Patna',
  'destinationDistrict': 'Muzaffarpur',
  'upfrontPaymentStatus': paid ? 'PAID_VERIFIED' : 'PENDING',
  'upfrontPaymentMethod': 'online',
  'logisticsPayment': {
    'totalPaise': 200300,
    'upfrontPaise': 80100,
    'finalPaise': 120200,
  },
};

http.Response _data(Object? data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  testWidgets(
    'GPS, polling, payment and resume leave the active ride panel stable',
    (tester) async {
      final requests = <String>[];
      Completer<http.Response>? paymentResponse;
      var paid = false;
      final session = _Session(
        ApiService(
          client: MockClient((request) async {
            final path = request.url.path;
            requests.add(path);
            if (path.endsWith('/customer-contact')) {
              return _data({
                'rideId': _rideId,
                'name': 'Niranjan Kumar',
                'callingNumber': '+919153787859',
              });
            }
            if (path == '/rides/driver/current-trip') {
              final response = paymentResponse;
              return response == null
                  ? _data(_ride(paid: paid, includeBooking: false))
                  : response.future;
            }
            fail('Unexpected request: $path');
          }),
        ),
      )..currentTrip = _ride();
      session.api.accessToken = 'local-test';
      session.api.userId = 'driver-test';
      await session.refreshCustomerContact();

      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: DriverNavigationScreen()),
        ),
      );
      final handle = find.byKey(const ValueKey('ride-details-handle'));
      final panel = find.byKey(const ValueKey('active-ride-panel'));
      for (var i = 0; i < 2; i++) {
        await tester.tap(handle);
        await tester.pumpAndSettle();
      }
      final height = tester.getSize(panel).height;
      final initialPayment = tester.widget(
        find.byType(LogisticsUpfrontPaymentCard),
      );
      final initialFacts = tester.widget(find.byType(RideDetails));

      for (var i = 0; i < 9; i++) {
        session.gpsTick();
        final sync = session.refresh(automatic: true);
        await tester.pump(const Duration(seconds: 20));
        expect(await sync, isTrue);
        await tester.pump();
        expect(find.text('Niranjan Kumar'), findsNWidgets(2));
        expect(find.text('Booking #4441604 · At pickup'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(
          tester.widget(find.byType(LogisticsUpfrontPaymentCard)),
          same(initialPayment),
        );
        expect(tester.widget(find.byType(RideDetails)), same(initialFacts));
        expect(tester.getSize(panel).height, height);
      }
      expect(
        requests.where((p) => p.endsWith('/customer-contact')),
        hasLength(1),
      );

      requests.clear();
      paymentResponse = Completer<http.Response>();
      final button = find.text('Refresh online payment status');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(session.paymentRefreshing, isTrue);
      expect(session.busy, isFalse);
      expect(await session.payLogisticsUpfrontOnline(_rideId), isFalse);
      expect(requests, ['/rides/driver/current-trip']);
      expect(find.text('Pending'), findsOneWidget);
      // The payment event arrives while an older snapshot is still in flight.
      paid = true;
      session.handleRideEvent('ride:lifecycle_updated', {'rideId': _rideId});
      expect(requests, ['/rides/driver/current-trip']);
      paymentResponse.complete(_data(_ride()));
      paymentResponse = null;
      await tester.pumpAndSettle();
      expect(find.text('Paid Verified'), findsOneWidget);
      expect(tester.widget(find.byType(RideDetails)), same(initialFacts));
      expect(requests, List.filled(2, '/rides/driver/current-trip'));
      session.handleRideEvent('ride:route_updated', {
        'rideId': _rideId,
        'segment': 'pickup',
        'routeVersion': 1,
        'route': {
          'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          'distanceMeters': 0,
          'durationSeconds': 0,
        },
      });
      await tester.pump();
      expect(session.liveNavigation?['routeVersion'], 1);
      expect(requests, hasLength(2));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Niranjan Kumar'), findsNWidgets(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Niranjan Kumar'), findsNWidgets(2));
      expect(find.text('Paid Verified'), findsOneWidget);
      expect(tester.getSize(panel).height, height);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/services/ride_request_presentation.dart';
import 'package:infurnus_driver/services/background_ride_request.dart';
import 'package:infurnus_driver/screens/driver/driver_home_screen.dart';
import 'package:infurnus_driver/widgets/incoming_ride_request_card.dart';
import 'package:infurnus_driver/widgets/trip_map.dart';

class RecordingBridge extends RideRequestBridge {
  final offers = <Map<String, dynamic>>[];
  @override
  Future<bool> present(Map<String, dynamic> offer) async {
    offers.add(offer);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'server time controls exact offer expiration despite device-clock skew',
    () {
      final local = DateTime.utc(2026, 11, 6, 10),
          server = DateTime.utc(2026, 11, 6, 8);
      final ride = {
        'dispatchExpiresAt': server
            .add(const Duration(seconds: 25))
            .toIso8601String(),
        'serverTime': server.toIso8601String(),
        '_receivedAt': local.toIso8601String(),
      };
      expect(
        offerRemaining(ride, now: local.add(const Duration(seconds: 24))),
        const Duration(seconds: 1),
      );
      expect(
        offerRemaining(ride, now: local.add(const Duration(seconds: 25))),
        Duration.zero,
      );
    },
  );
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
      'approved home at width $width has four backend-bound today cards and no embedded map or earnings',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session =
            DriverSession(
                api: ApiService(
                  client: MockClient((_) async => http.Response('{}', 200)),
                ),
              )
              ..isPreview = true
              ..account = {'firstName': 'Local', 'lastName': 'Driver'}
              ..todaySummary = {
                'totalRequests': 23,
                'accepted': 14,
                'rejected': 9,
                'totalRides': 11,
              };
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: session,
            child: const MaterialApp(home: DriverHomeScreen()),
          ),
        );
        await tester.pump();
        for (final label in [
          'Total Requests',
          'Accepted',
          'Rejected',
          'Total Rides',
          '23',
          '14',
          '9',
          '11',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byType(TripMap), findsNothing);
        expect(find.textContaining('Earnings'), findsNothing);
        expect(find.textContaining('₹'), findsNothing);
        expect(find.byType(Switch), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
  testWidgets(
    'expired request disables both actions and renders real metadata without guessing hidden drop',
    (tester) async {
      final ride = {
        'id': 'ride',
        'sector': 'logistics',
        'vehicleCategory': 'tata_407',
        'pickupAddress': 'Selected pickup',
        'rideInformation': {
          'fare': {'amount': 735},
          'totalDistance': {'meters': 72400},
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomingRideRequestCard(
              ride: ride,
              remaining: Duration.zero,
              accept: () {},
              reject: () {},
            ),
          ),
        ),
      );
      expect(find.text('Selected pickup'), findsOneWidget);
      expect(find.text('72.4 km'), findsOneWidget);
      expect(find.text('₹735'), findsOneWidget);
      expect(find.text('Available after PIN verification'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Accept'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Reject'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  test('background receiver reconciles via bearer GET only, using server offer data instead of push addresses', () async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'role': 'driver',
        'providerMode': 'driver',
        'accessToken': 'local-test',
      });
    final bridge = RecordingBridge(), calls = <String>[];
    final transport = MockClient((r) async {
      calls.add('${r.method} ${r.url.path}');
      expect(r.headers['Authorization'], 'Bearer local-test');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'offer',
              'pickupAddress': 'Authoritative pickup',
              'dispatchExpiresAt': DateTime.now()
                  .add(const Duration(seconds: 25))
                  .toIso8601String(),
            },
          ],
        }),
        200,
      );
    });
    expect(
      await presentBackgroundOffer(
        {
          'type': 'ride.created',
          'rideId': 'offer',
          'pickupAddress': 'Untrusted push address',
        },
        store: store,
        transport: transport,
        bridge: bridge,
      ),
      isTrue,
    );
    expect(calls, ['GET /rides/driver/available']);
    expect(bridge.offers.single['pickupAddress'], 'Authoritative pickup');
    transport.close();
  });
  test(
    'revoked and unauthorized background offers never create a native window',
    () async {
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'role': 'driver',
          'providerMode': 'driver',
          'accessToken': 'local-test',
        });
      final bridge = RecordingBridge();
      final empty = MockClient(
        (_) async => http.Response(jsonEncode({'data': []}), 200),
      );
      expect(
        await presentBackgroundOffer(
          {'rideId': 'gone'},
          store: store,
          transport: empty,
          bridge: bridge,
        ),
        isTrue,
      );
      expect(bridge.offers, isEmpty);
      empty.close();
      final denied = MockClient((_) async => http.Response('{}', 401));
      expect(
        await presentBackgroundOffer(
          {'rideId': 'gone'},
          store: store,
          transport: denied,
          bridge: bridge,
        ),
        isFalse,
      );
      expect(bridge.offers, isEmpty);
      denied.close();
    },
  );
  test('native bridge consumes each action through the platform handoff without persisting tokens', () async {
    const channel = MethodChannel('infurnus/ride_requests');
    var taken = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'takeAction' && !taken) {
            taken = true;
            return jsonEncode({
              'rideId': 'ride',
              'action': 'accept',
              'deadline': DateTime.now()
                  .add(const Duration(seconds: 20))
                  .millisecondsSinceEpoch,
            });
          }
          return null;
        });
    expect(
      (await RideRequestBridge(android: true).takeAction())?['action'],
      'accept',
    );
    expect(await RideRequestBridge(android: true).takeAction(), isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/notification_service.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';
import 'package:infurnus_driver/widgets/operations.dart';

// Onboarding/GPS/socket SDK setup is independent of this handler unit test.
// Registration + actual socket receipt are covered by the backend E2E test.
class HandlerSession extends DriverSession {
  bool verified = true;
  HandlerSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => verified;
  @override
  Future<bool> refresh({bool automatic = false}) => run(() async {
    final data = await api.request('GET', '/rides/driver/available');
    rides = (data as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  });
}

void main() {
  final trace = jsonDecode(
    File('test/fixtures/actual_notification_route.json').readAsStringSync(),
  ) as Map;
  testWidgets(
    'actual backend offer data reaches the real Driver handler and observable offer card',
    (tester) async {
      var calls = 0;
      final paths = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          calls++;
          paths.add(r.url.path);
          return http.Response(
            jsonEncode({'success': true, 'data': trace['available']}),
            200,
          );
        }),
      );
      final session = HandlerSession(api);
      addTearDown(session.dispose);
      session.handleRideEvent('ride:incoming', trace['offer']);
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
      expect(paths, ['/rides/driver/available']);
      expect(session.rides.single['id'], trace['offer']['ride']['id']);
      final row = session.rides.single;
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RideOfferCard(
                  ride: row,
                  clock: () => DateTime.parse(row['serverTime']),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Accept'), findsOneWidget);
      expect(
        find.text(inrRupees(row['rideInformation']['fare']['amount'])),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('events during a busy operation coalesce and reconcile removed or cancelled offers', () async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((r) async {
        calls++;
        return http.Response(jsonEncode({'success': true, 'data': []}), 200);
      }),
    );
    final session = HandlerSession(api);
    addTearDown(session.dispose);
    session.rides = [Map<String, dynamic>.from(trace['available'][0])];
    final hold = Completer<void>();
    final action = session.run(() => hold.future);
    session.handleRideEvent('ride:incoming', trace['offer']);
    session.handleRideEvent('ride:taken', {
      'rideId': trace['offer']['ride']['id'],
    });
    expect(calls, 0);
    hold.complete();
    await action;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 1);
    expect(session.rides, isEmpty);
    session.verified = false;
    session.handleRideEvent('ride:incoming', trace['offer']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });
  test('foreground FCM handler rejects stale, duplicate and logged-out data without presentation claims', () {
    var handled = 0;
    final api = ApiService(
      client: MockClient((r) async => http.Response('{}', 200)),
    )..accessToken = 'isolated-test-credential';
    addTearDown(api.dispose);
    final service = DriverNotificationService(
      api: api,
      onRideUpdate: (_) => handled++,
    );
    addTearDown(service.dispose);
    final data = {
      'rideId': trace['offer']['ride']['id'],
      'notificationId': 'fixture-message',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };
    expect(service.handleForegroundData(data), isTrue);
    expect(service.handleForegroundData(data), isFalse);
    expect(handled, 1);
    expect(
      service.handleForegroundData({
        ...data,
        'notificationId': 'expired',
        'expiresAt': '2000-01-01T00:00:00Z',
      }),
      isFalse,
    );
    api.accessToken = null;
    expect(
      service.handleForegroundData({...data, 'notificationId': 'logged-out'}),
      isFalse,
    );
    expect(handled, 1);
  });
  test('debug preview is explicitly unauthenticated and has no fake backend credential', () {
    final session = DriverSession(
      api: ApiService(
        client: MockClient((r) async => http.Response('{}', 200)),
      ),
    );
    session.enablePreview();
    expect(session.authenticated, isFalse);
    expect(session.api.accessToken, isNull);
    session.dispose();
  });
}

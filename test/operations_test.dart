import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:infurnus_driver/screens/common/notification_inbox_screen.dart';
import 'package:infurnus_driver/screens/common/notification_preferences_screen.dart';
import 'package:infurnus_driver/services/payout_request.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/models/route_geometry.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/notification_service.dart';
import 'package:infurnus_driver/widgets/operations.dart';
import 'package:infurnus_driver/screens/fleet/fleet_reports_screen.dart';

void main() {
  test('fleet CSV escapes spreadsheet formulas and quoted content', () {
    expect(
      fleetCsvCell('=HYPERLINK("https://example.invalid")'),
      startsWith('"\''),
    );
    expect(fleetCsvCell('Vehicle "A"'), '"Vehicle ""A"""');
  });
  testWidgets(
    'fleet trip status filter changes actual server records displayed',
    (tester) async {
      final api = ApiService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'active',
                  'vehiclePlate': 'ACTUAL-A',
                  'status': 'in_progress',
                  'pickupAddress': 'Active pickup',
                },
                {
                  'id': 'complete',
                  'vehiclePlate': 'ACTUAL-B',
                  'status': 'completed',
                  'pickupAddress': 'Completed pickup',
                },
              ],
            }),
            200,
          ),
        ),
      );
      final session = DriverSession(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(
            theme: Ops.theme,
            home: const FleetReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Active pickup'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Active pickup'), findsNothing);
      expect(find.textContaining('Completed pickup'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'notification preference failure keeps the server-confirmed toggle state',
    (tester) async {
      final calls = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          calls.add(request.method);
          return request.method == 'GET'
              ? http.Response(
                  '{"success":true,"data":{"pushNotificationsEnabled":true,"emailNotificationsEnabled":false,"smsNotificationsEnabled":false}}',
                  200,
                )
              : http.Response(
                  '{"error":{"message":"Preference could not be saved"}}',
                  503,
                );
        }),
      )..userId = 'owner';
      final session = DriverSession(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(
            theme: Ops.theme,
            home: const NotificationPreferencesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push notifications'));
      await tester.pumpAndSettle();
      expect(calls, ['GET', 'PATCH']);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .first
            .value,
        isTrue,
      );
      expect(find.text('Preference could not be saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test(
    'uncertain payout retry reuses persisted amount and idempotency key',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final requests = <Map>[];
      var attempt = 0;
      final api =
          ApiService(
              client: MockClient((request) async {
                requests.add(jsonDecode(request.body) as Map);
                attempt++;
                return attempt == 1
                    ? http.Response(
                        '{"error":{"message":"Temporary failure"}}',
                        503,
                      )
                    : http.Response(
                        '{"success":true,"data":{"id":"payout","status":"REQUESTED"}}',
                        201,
                      );
              }),
            )
            ..userId = 'owner'
            ..accessToken = 'fixture';
      final first = PayoutRequest(api);
      await expectLater(first.submit(10000), throwsA(isA<ApiException>()));
      final retry = PayoutRequest(api);
      await expectLater(retry.submit(20000), throwsA(isA<ApiException>()));
      await retry.submit(10000);
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(await retry.pending(), isNull);
      api.dispose();
    },
  );
  testWidgets(
    'inbox loads server unread count and confirms mark-all before updating',
    (tester) async {
      final methods = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          methods.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': request.method == 'GET'
                  ? {
                      'items': [
                        {
                          'id': 'actual-id',
                          'title': 'Actual alert',
                          'body': 'Server message',
                          'readAt': null,
                        },
                      ],
                      'unreadCount': 1,
                    }
                  : {'updated': 1},
            }),
            200,
          );
        }),
      );
      final session = DriverSession(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(
            theme: Ops.theme,
            home: const ServerNotificationInbox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications · 1 unread'), findsOneWidget);
      expect(find.text('Actual alert'), findsOneWidget);
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications · 0 unread'), findsOneWidget);
      expect(methods, [
        'GET /notifications/inbox',
        'PATCH /notifications/inbox/read-all',
      ]);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test('road geometry decodes known provider polyline', () {
    final points = decodeRoutePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, [
      [38.5, -120.2],
      [40.7, -120.95],
      [43.252, -126.453],
    ]);
  });
  test('malformed and missing road geometry is rejected', () {
    for (final geometry in ['', '_', 'x', '~~~~~~~']) {
      expect(() => decodeRoutePolyline(geometry), throwsFormatException);
    }
  });
  test('currency follows INR grouping and never invents a missing balance', () {
    expect(inr('12345678'), contains('1,23,456.78'));
    expect(inr(null), 'Unavailable');
    expect(inr('-150'), contains('1.50'));
  });
  test('notification payload cannot choose arbitrary navigation', () {
    expect(notificationDestination({'route': '/admin/dashboard'}), isNull);
    expect(
      notificationDestination({'rideId': 'ride', 'route': '/admin/dashboard'}),
      '/driver/dashboard',
    );
    expect(notificationDestination({'type': 'PAYOUT_UPDATED'}), isNull);
    expect(notificationDestination({'rideId': ''}), isNull);
  });
  testWidgets(
    'earnings uses ledger API and period filter changes displayed data',
    (tester) async {
      final paths = <String>[];
      final today = DateTime.now().toUtc();
      final yesterday = today.subtract(const Duration(days: 1));
      final api = ApiService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'periods': [
                  {
                    'period': 'daily',
                    'netPaise': '10000',
                    'grossPaise': '12000',
                    'commissionPaise': '2000',
                    'adjustmentPaise': '0',
                  },
                  {
                    'period': 'monthly',
                    'netPaise': '30000',
                    'grossPaise': '32000',
                    'commissionPaise': '2000',
                    'adjustmentPaise': '0',
                  },
                ],
                'days': [
                  {'day': today.toIso8601String(), 'netPaise': '10000'},
                  {'day': yesterday.toIso8601String(), 'netPaise': '20000'},
                ],
              },
            }),
            200,
          );
        }),
      );
      final session = DriverSession(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(theme: Ops.theme, home: const LedgerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths, ['/provider/earnings']);
      expect(find.text('₹100.00'), findsWidgets);
      expect(find.text('₹300.00'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month').last);
      await tester.pumpAndSettle();
      expect(find.text('₹300.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('wallet failure exposes retry without demo money', (
    tester,
  ) async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'message': 'Wallet unavailable'},
          }),
          503,
        );
      }),
    );
    final session = DriverSession(api: api);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          theme: Ops.theme,
          home: const LedgerScreen(wallet: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('8,640'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'all trip tab includes active server trip and no sample bookings',
    (tester) async {
      final session = DriverSession();
      session.history = {
        'rides': [
          {
            'id': 'actual-active',
            'status': 'in_progress',
            'pickupAddress': 'Actual pickup',
            'destinationAddress': 'Actual destination',
          },
        ],
      };
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(theme: Ops.theme, home: const TripsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Actual pickup'), findsOneWidget);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('No trips in this view.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

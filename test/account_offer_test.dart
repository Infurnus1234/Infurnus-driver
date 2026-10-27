import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/account_details_card.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';

void main() {
  testWidgets(
    'custom type is selected only after backend persistence and catalog reload',
    (tester) async {
      final types = <Map<String, dynamic>>[];
      Map<String, String>? selected;
      final calls = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          if (r.method == 'POST') {
            final body = jsonDecode(r.body) as Map;
            expect(body, {'sector': 'logistics', 'name': 'My Truck'});
            final entry = <String, dynamic>{
              'name': 'My Truck',
              'code': 'custom_test',
              'sector': 'logistics',
              'custom': true,
            };
            types.add(entry);
            return http.Response(
              jsonEncode({'success': true, 'data': entry}),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'sectors': ['passenger', 'logistics'],
                'types': types,
              },
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await selectFleetVehicleCategory(context, api);
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('logistics').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My Truck');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add "My Truck"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(selected, {'sector': 'logistics', 'category': 'custom_test'});
      expect(calls, [
        'GET /provider/vehicle-catalog',
        'POST /provider/vehicle-catalog/custom',
        'GET /provider/vehicle-catalog',
      ]);
    },
  );

  testWidgets(
    'failed profile save keeps the edited contact available for retry',
    (tester) async {
      final session = DriverSession(
        api: ApiService(
          client: MockClient(
            (r) async => r.method == 'PATCH'
                ? http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {'message': 'Temporary outage'},
                    }),
                    503,
                  )
                : http.Response(
                    jsonEncode({
                      'success': true,
                      'data': {
                        'firstName': 'Fleet',
                        'lastName': 'Owner',
                        'email': 'owner@example.test',
                      },
                    }),
                    200,
                  ),
          ),
        ),
      );
      session.api.role = 'fleet_owner';
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AccountDetailsCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit Personal Information'));
      await tester.tap(find.text('Edit Personal Information'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '+919876543210',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary outage'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, '+919876543210'),
        findsOneWidget,
      );
      expect(find.text('Profile saved'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'account details retain collapse state and save contacts without OTP',
    (tester) async {
      final calls = <String>[];
      var saved = <String, dynamic>{
        'firstName': 'Test',
        'lastName': 'Driver',
        'email': 'test@example.test',
      };
      final session = DriverSession(
        api: ApiService(
          client: MockClient((r) async {
            calls.add('${r.method} ${r.url.path}');
            if (r.method == 'PATCH') {
              saved = {...saved, ...jsonDecode(r.body) as Map<String, dynamic>};
            }
            return http.Response(
              jsonEncode({'success': true, 'data': saved}),
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AccountDetailsCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not provided'), findsOneWidget);
      await tester.tap(find.byTooltip('Collapse account details'));
      await tester.pump();
      expect(find.text('Mobile Number'), findsNothing);
      session.notifyListeners();
      await tester.pump();
      expect(find.text('Mobile Number'), findsNothing);
      await tester.tap(find.byTooltip('Expand account details'));
      await tester.pump();
      await tester.ensureVisible(find.text('Edit Personal Information'));
      await tester.tap(find.text('Edit Personal Information'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '+919876543210',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved['phone'], '+919876543210');
      expect(calls, ['GET /provider/account', 'PATCH /provider/account']);
      expect(find.text('Profile saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'offer countdown follows server clock and cannot restart on rebuild',
    (tester) async {
      final session = DriverSession(
        api: ApiService(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      var clock = DateTime.utc(2030);
      final ride = <String, dynamic>{
        '_receivedAt': clock.toIso8601String(),
        'id': 'offer-test',
        'serverTime': '2020-01-01T00:00:00Z',
        'dispatchExpiresAt': '2020-01-01T00:00:03Z',
        'pickupAddress': 'Pickup',
        'rideInformation': {
          'fare': {'amount': 125, 'authority': 'booked'},
        },
      };
      Widget screen() => ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RideOfferCard(
                key: const ValueKey('offer-test'),
                ride: ride,
                clock: () => clock,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      expect(find.text('Time remaining: 0:03'), findsOneWidget);
      expect(find.text('Estimated fare'), findsOneWidget);
      clock = clock.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(screen());
      expect(find.text('Time remaining: 0:01'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      clock = clock.add(const Duration(seconds: 2));
      await tester.pumpWidget(screen());
      expect(find.text('Offer expired'), findsOneWidget);
      final accept = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Accept'),
      );
      expect(accept.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

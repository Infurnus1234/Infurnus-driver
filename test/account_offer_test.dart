import 'support/active_catalog_fixture.dart';

import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';
import 'package:infurnus_driver/providers/provider_assets.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/account_details_card.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';

void main() {
  testWidgets(
    'Logistics exposes server-configured types and labels Passenger inventory as Rental',
    (tester) async {
      Map<String, dynamic>? selected;
      final calls = <String>[];
      final api = ApiService(
        client: activeCatalogClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'sectors': ['passenger', 'logistics'],
                'types': [
                  {'name': 'Sedan', 'code': 'sedan', 'sector': 'passenger'},
                  {
                    'name': '3-Wheeler (Goods)',
                    'code': 'three_wheeler_goods',
                    'sector': 'logistics',
                  },
                  {
                    'name': 'Mini Truck (Tata Ace)',
                    'code': 'mini_truck_tata_ace',
                    'sector': 'logistics',
                  },
                  {
                    'name': 'Pickup 8ft',
                    'code': 'pickup_8ft',
                    'sector': 'logistics',
                  },
                  {
                    'name': 'Tata 407',
                    'code': 'tata_407',
                    'sector': 'logistics',
                  },
                  {
                    'name': '207 Heavy',
                    'code': '207_heavy',
                    'sector': 'logistics',
                  },
                ],
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
      expect(find.text('passenger'), findsNothing);
      await tester.tap(find.text('Logistics').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      for (final name in [
        '3-Wheeler (Goods)',
        'Mini Truck (Tata Ace)',
        'Pickup 8ft',
        'Tata 407',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('207 Heavy'), findsOneWidget);
      await tester.tap(find.text('Tata 407').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(selected, {'sector': 'logistics', 'category': 'tata_407'});
      expect(calls, ['GET /provider/vehicle-catalog']);
    },
  );

  testWidgets(
    'Admin-published options appear after reopening and Fleet cannot create catalog types',
    (tester) async {
      final types = <Map<String, dynamic>>[
        {
          'id': 'existing',
          'code': 'ambulance',
          'name': 'Ambulance',
          'sector': 'service',
          'active': true,
        },
        {
          'id': 'inactive',
          'code': 'inactive',
          'name': 'Inactive service',
          'catalogVisible': false,
          'sector': 'service',
          'active': false,
        },
      ];
      final calls = <String>[];
      Map<String, dynamic>? selected;
      final api = ApiService(
        client: activeCatalogClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'sectors': ['service'],
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
      Future<void> open() async {
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Service').last);
        await tester.pumpAndSettle();
        expect(find.text('Add custom vehicle type'), findsNothing);
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        expect(find.text('Inactive service'), findsNothing);
      }

      await open();
      await tester.tap(find.text('Ambulance').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(selected, {'sector': 'service', 'category': 'ambulance'});
      types.add({
        'id': 'new',
        'code': 'new_admin_service',
        'name': 'New Admin service',
        'sector': 'service',
        'active': true,
      });
      await open();
      await tester.tap(find.text('New Admin service').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(selected, {'sector': 'service', 'category': 'new_admin_service'});
      expect(calls, [
        'GET /provider/vehicle-catalog',
        'GET /provider/vehicle-catalog',
      ]);
      api.dispose();
    },
  );

  test(
    'search consumes the backend catalog and preserves inventory identifiers',
    () async {
      final api = ApiService(
        client: activeCatalogClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'types': [
                  {
                    'id': 'mini-id',
                    'code': 'mini',
                    'name': 'Mini',
                    'sector': 'passenger',
                    'active': true,
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );
      final results = await VehicleCatalogRepository(api: api)
          .searchVehicles('Mini');
      expect(results.single.modelName, 'Mini');
      expect(results.single.category, 'passenger');
      expect(results.single.id, 'mini-id');
      api.dispose();
    },
  );

  test(
    'vehicle save validation rejects unknown sectors before any API call',
    () async {
      var requests = 0;
      final api = ApiService(
        client: activeCatalogClient((request) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
      final assets = ProviderAssets(api);
      expect(await assets.saveVehicle({'sector': 'unknown'}), isFalse);
      expect(assets.error, contains('Select a valid vehicle category.'));
      expect(requests, 0);
      assets.dispose();
      api.dispose();
    },
  );

  testWidgets(
    'failed profile save keeps the edited contact available for retry',
    (tester) async {
      final session = DriverSession(
        api: ApiService(
          client: activeCatalogClient(
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
      expect(
        find.text('We couldn\'t complete this request. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Temporary outage'), findsNothing);
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
          client: activeCatalogClient((r) async {
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
          client: activeCatalogClient((_) async => http.Response('{}', 200)),
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
      expect(find.text('Ride Price'), findsOneWidget);
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

import 'support/premium_location_fixture.dart';
import 'support/active_catalog_fixture.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';

void main() {
  setUp(configureOperatingMap);
  const labels = {
    'passenger': 'Rental',
    'logistics': 'Logistics',
    'premium': 'Premium',
    'service': 'Service',
  };
  for (final sector in labels.keys) {
    testWidgets(
      '${labels[sector]} refresh accepts priced and unpriced Admin options and excludes hidden options',
      (tester) async {
        final types = <Map<String, dynamic>>[
          {
            'id': 'old',
            'code': 'existing',
            'name': 'Existing option',
            'sector': sector,
            'active': true,
          },
          {
            'id': 'inactive',
            'code': 'inactive',
            'name': 'Inactive option',
            'sector': sector,
            'registrationActive': false,
            'active': false,
          },
          {
            'id': 'hidden',
            'code': 'hidden',
            'name': 'Hidden option',
            'sector': sector,
            'active': true,
            'catalogVisible': false,
          },
        ];
        final calls = <String>[];
        final api = ApiService(
          store: MemorySessionStore(),
          client: activeCatalogClient((request) async {
            calls.add('${request.method} ${request.url.path}');
            if (request.url.path == '/maps/geocode') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'latitude': 26.65, 'longitude': 84.9167},
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'sectors': ['passenger', 'logistics', 'premium', 'service'],
                  'types': types,
                  'operatingCities': [
                    {'id': 'patna', 'name': 'Patna'},
                  ],
                },
              }),
              200,
            );
          }),
        );
        addTearDown(api.dispose);
        Map<String, dynamic>? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await selectFleetVehicleCategory(context, api);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>).first);
          await tester.pumpAndSettle();
          for (final label in labels.values) {
            expect(find.text(label), findsOneWidget);
          }
          await tester.tap(find.text(labels[sector]!).last);
          await tester.pumpAndSettle();
        }

        Future<void> choose(String name, String code) async {
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
          await tester.pumpAndSettle();
          expect(find.text('Inactive option'), findsNothing);
          expect(find.text('Hidden option'), findsNothing);
          await tester.tap(find.text(name).last);
          await tester.pumpAndSettle();
          if (sector == 'premium') {
            await selectTestOperatingLocation(tester);
          }
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(selected, {
            'sector': sector,
            'category': code,
            if (sector == 'premium')
              'operatingLocation': {
                'address': 'Motihari Bihar',
                'latitude': 26.65,
                'longitude': 84.9167,
              },
          });
        }

        await open();
        await choose('Existing option', 'existing');
        types.first['catalogVisible'] = false;
        types.add({
          'id': 'new',
          'code': 'admin_added',
          'name': 'Admin added option',
          'sector': sector,
          'active': true,
        });
        await open();
        expect(find.text('Existing option'), findsNothing);
        await choose('Admin added option', 'admin_added');
        types.last['catalogVisible'] = false;
        await open();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        types.last['catalogVisible'] = true;
        types.last['name'] = 'Renamed by Admin';
        await open();
        await choose('Renamed by Admin', 'admin_added');
        expect(
          calls.where((c) => c == 'GET /provider/vehicle-catalog').length,
          4,
        );
      },
    );
  }
  testWidgets('a hidden initial selection cannot enable Continue', (
    tester,
  ) async {
    final api = ApiService(
      store: MemorySessionStore(),
      client: activeCatalogClient(
        (request) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sectors': ['logistics'],
              'types': [
                {
                  'id': 'old',
                  'code': 'old',
                  'name': 'Old',
                  'sector': 'logistics',
                  'active': false,
                  'catalogVisible': false,
                },
              ],
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => selectFleetVehicleCategory(
                context,
                api,
                initial: {'sector': 'logistics', 'category': 'old'},
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    expect(find.text('Old'), findsNothing);
  });
}

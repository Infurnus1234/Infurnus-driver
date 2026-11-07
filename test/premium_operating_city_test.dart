import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/active_catalog_fixture.dart';

import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';

import 'support/premium_location_fixture.dart';

void main() {
  setUp(configureOperatingMap);
  for (final address in [
    'Patna Bihar',
    'Muzaffarpur Bihar',
    'Motihari Bihar',
    'Bettiah Bihar',
    'Gaya Bihar',
  ]) {
    testWidgets(
      'Premium location search accepts $address without supported-city options',
      (tester) async {
        Map<String, dynamic>? result;
        final requests = <String>[];
        final api = ApiService(
          client: activeCatalogClient((request) async {
            requests.add(request.url.path);
            if (request.url.path == '/maps/geocode') {
              expect(jsonDecode(request.body), {'address': address});
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
                  'sectors': ['premium'],
                  'types': [
                    {
                      'sector': 'premium',
                      'code': 'thar',
                      'name': 'Mahindra Thar',
                      'catalogVisible': true,
                      'active': false,
                    },
                  ],
                  'operatingCities': [],
                },
              }),
              200,
            );
          }),
        );
        addTearDown(api.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await selectFleetVehicleCategory(
                      context,
                      api,
                      initial: {'sector': 'premium', 'category': 'thar'},
                    );
                  },
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue'),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Supported Bihar city *'), findsNothing);
        await selectTestOperatingLocation(tester, address: address);
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(result, {
          'sector': 'premium',
          'category': 'thar',
          'operatingLocation': {
            'address': address,
            'latitude': 26.65,
            'longitude': 84.9167,
          },
        });
        expect(requests, ['/provider/vehicle-catalog', '/maps/geocode']);
      },
    );
  }
}

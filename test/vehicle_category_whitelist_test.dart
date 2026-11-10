import 'support/active_catalog_fixture.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/models/vehicle_category_policy.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';

class WhitelistFixtureSession extends DriverSession {
  WhitelistFixtureSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

http.Response _ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  group('VehicleCategoryPolicy & Registration Dialog Tests', () {
    test('Allows all 8 approved sector and code combinations', () {
      expect(
        VehicleCategoryPolicy.allowsCode('logistics', 'cargo_207_heavy'),
        isTrue,
      );
      expect(
        VehicleCategoryPolicy.allowsCode('logistics', 'three_wheeler'),
        isTrue,
      );
      expect(
        VehicleCategoryPolicy.allowsCode('logistics', 'cargo_407'),
        isTrue,
      );
      expect(
        VehicleCategoryPolicy.allowsCode('logistics', 'mini_truck'),
        isTrue,
      );
      expect(VehicleCategoryPolicy.allowsCode('logistics', 'tata_407'), isTrue);
      expect(VehicleCategoryPolicy.allowsCode('service', 'ambulance'), isTrue);
      expect(VehicleCategoryPolicy.allowsCode('premium', 'thar'), isTrue);
      expect(VehicleCategoryPolicy.allowsCode('rental', 'thar'), isTrue);
    });

    test(
      'Keeps server-configured inventory selectable for Rental and Service',
      () {
        expect(VehicleCategoryPolicy.isSelectableSector('passenger'), isTrue);
        expect(VehicleCategoryPolicy.allowsCode('other', 'sedan'), isFalse);
        expect(VehicleCategoryPolicy.allowsCode('passenger', ''), isFalse);
        expect(VehicleCategoryPolicy.allowsCode('passenger', 'sedan'), isTrue);
        expect(
          VehicleCategoryPolicy.allowsCode('logistics', 'pickup_8ft'),
          isTrue,
        );
        expect(VehicleCategoryPolicy.allowsCode('service', 'towing'), isTrue);
        expect(
          VehicleCategoryPolicy.allowsCode('premium', 'helicopter'),
          isTrue,
        );
      },
    );

    test('Premium thar and rental thar are independent sector/code pairs', () {
      expect(VehicleCategoryPolicy.allowsCode('premium', 'thar'), isTrue);
      expect(VehicleCategoryPolicy.allowsCode('rental', 'thar'), isTrue);
    });

    testWidgets(
      'Legacy vehicle registration readability widget test using ProviderAssetsScreen and mock fixture data',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api =
            ApiService(
                client: activeCatalogClient((r) async {
                  final path = r.url.path;
                  if (path == '/partners/me') {
                    return _ok({
                      'id': 'test-partner-01',
                      'businessName': 'Mock Fixture Fleet Partner',
                      'approvalStatus': 'approved',
                    });
                  }
                  if (path == '/fleet/vehicles' ||
                      path == '/partners/vehicles') {
                    return _ok([
                      {
                        'id': 'veh-legacy-1',
                        'make': 'Tata',
                        'model': 'Ace',
                        'plateNumber': 'BR 01 X 9999',
                        'sector': 'logistics',
                        'category': 'pickup_8ft', // Legacy category unselectable for new registration
                        'verificationStatus': 'approved',
                        'isActive': true,
                      },
                    ]);
                  }
                  if (path.contains('/documents')) {
                    return _ok([
                      {
                        'id': 'doc-rc-1',
                        'vehicleId': 'veh-legacy-1',
                        'documentType': 'vehicle_rc',
                        'status': 'approved',
                      },
                    ]);
                  }
                  if (path == '/provider/approvals') {
                    return _ok([]);
                  }
                  if (path.contains('/earnings')) {
                    return _ok(<String, dynamic>{});
                  }
                  return _ok([]);
                }),
              )
              ..role = 'fleet_owner'
              ..providerMode = 'fleet_owner';

        final session = WhitelistFixtureSession(api)
          ..roleEnrolment = {'dashboardAccessible': true};

        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: MaterialApp(
              theme: Ops.theme,
              home: const ProviderAssetsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Navigate to Vehicles tab
        await tester.tap(find.text('Vehicles').last);
        await tester.pumpAndSettle();

        // Verify legacy vehicle plate number and legacy category are visible on screen
        expect(find.textContaining('BR 01 X 9999'), findsOneWidget);
        expect(find.textContaining('pickup_8ft'), findsOneWidget);

        // Open vehicle documents dialog
        await tester.tap(find.text('Vehicle documents').last);
        await tester.pumpAndSettle();

        // Verify Vehicle RC document label is visible in dialog
        expect(find.text('Vehicle Documents'), findsOneWidget);
        expect(find.text('Vehicle RC'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Verify all 8 approved sector/code pairs through real VehicleCategoryDialog widget',
      (tester) async {
        final catalogData = {
          'sectors': ['logistics', 'service', 'premium', 'rental'],
          'operatingCities': [
            {'id': 'patna', 'name': 'Patna'},
          ],
          'types': [
            {
              'sector': 'logistics',
              'code': 'cargo_207_heavy',
              'name': '207 Heavy',
            },
            {
              'sector': 'logistics',
              'code': 'three_wheeler',
              'name': '3-Wheeler (Goods)',
            },
            {'sector': 'logistics', 'code': 'cargo_407', 'name': '407 Cargo'},
            {
              'sector': 'logistics',
              'code': 'mini_truck',
              'name': 'Mini Truck (Tata Ace)',
            },
            {'sector': 'logistics', 'code': 'tata_407', 'name': 'Tata 407'},
            {'sector': 'service', 'code': 'ambulance', 'name': 'Ambulance'},
            {'sector': 'premium', 'code': 'thar', 'name': 'Mahindra Thar'},
            {'sector': 'rental', 'code': 'thar', 'name': 'Off-road SUV (Thar)'},
          ],
        };

        final api = ApiService(
          client: activeCatalogClient((request) async {
            if (request.url.path.endsWith('/provider/vehicle-catalog')) {
              return _ok(catalogData);
            }
            return http.Response('not found', 404);
          }),
        );

        final pairs = [
          {
            'sector': 'logistics',
            'code': 'cargo_207_heavy',
            'name': '207 Heavy',
          },
          {
            'sector': 'logistics',
            'code': 'three_wheeler',
            'name': '3-Wheeler (Goods)',
          },
          {'sector': 'logistics', 'code': 'cargo_407', 'name': '407 Cargo'},
          {
            'sector': 'logistics',
            'code': 'mini_truck',
            'name': 'Mini Truck (Tata Ace)',
          },
          {'sector': 'logistics', 'code': 'tata_407', 'name': 'Tata 407'},
          {'sector': 'service', 'code': 'ambulance', 'name': 'Ambulance'},
          {'sector': 'premium', 'code': 'thar', 'name': 'Mahindra Thar'},
          {'sector': 'rental', 'code': 'thar', 'name': 'Off-road SUV (Thar)'},
        ];

        for (final pair in pairs) {
          Map<String, dynamic>? selectedResult;

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      selectedResult = await selectFleetVehicleCategory(
                        context,
                        api,
                        initial: {
                          'sector': pair['sector'],
                          'category': pair['code'],
                        },
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Tap configured type dropdown
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
          await tester.pumpAndSettle();

          expect(find.text(pair['name']!), findsNWidgets(2));
          await tester.tap(find.text(pair['name']!).last);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          expect(selectedResult, {
            'sector': pair['sector']!,
            'category': pair['code']!,
          });
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'Verify premium/thar and rental/thar remain independent in dialog',
      (tester) async {
        final api = ApiService(
          client: activeCatalogClient((request) async {
            if (request.url.path.endsWith('/provider/vehicle-catalog')) {
              return _ok({
                'sectors': ['premium', 'rental'],
                'types': [
                  {
                    'sector': 'premium',
                    'code': 'thar',
                    'name': 'Mahindra Thar',
                  },
                  {
                    'sector': 'rental',
                    'code': 'thar',
                    'name': 'Off-road SUV (Thar)',
                  },
                ],
              });
            }
            return http.Response('not found', 404);
          }),
        );

        Map<String, dynamic> selectedResult = {};

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final res = await selectFleetVehicleCategory(
                      context,
                      api,
                      initial: {'sector': 'rental', 'category': 'thar'},
                    );
                    if (res != null) selectedResult = res;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();

        expect(find.text('Off-road SUV (Thar)'), findsNWidgets(2));
        await tester.tap(find.text('Off-road SUV (Thar)').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(selectedResult, {'sector': 'rental', 'category': 'thar'});
      },
    );
  });
}

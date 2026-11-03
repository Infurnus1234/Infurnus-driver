import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';

class _FleetSession extends DriverSession {
  _FleetSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  testWidgets(
    'successful Driver creation refreshes the Fleet list immediately',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var created = false, listReads = 0;
      final profile = {
        'userId': 'driver',
        'firstName': 'TEST_SAMPLE',
        'lastName': 'Created',
        'email': 'driver@example.invalid',
        'verificationStatus': 'pending',
        'licenseNumber': 'TEST_LICENSE',
        'licenseExpiry': '2090-01-01',
        'assignedVehicle': null,
      };
      final api =
          ApiService(
              client: MockClient((r) async {
                dynamic data = <dynamic>[];
                switch (r.url.path) {
                  case '/partners/me':
                    data = {
                      'id': 'fleet',
                      'businessName': 'TEST Fleet',
                      'approvalStatus': 'pending',
                    };
                  case '/provider/earnings':
                  case '/fleet/earnings':
                    data = <String, dynamic>{};
                  case '/provider/managed-drivers':
                    if (r.method == 'POST') {
                      created = true;
                      data = {
                        'userId': 'driver',
                        'verificationStatus': 'pending',
                      };
                    } else {
                      listReads++;
                      data = created ? [profile] : <dynamic>[];
                    }
                  case '/provider/managed-drivers/driver':
                    data = {
                      'profile': profile,
                      'requirements': <dynamic>[],
                      'documents': <dynamic>[],
                    };
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  r.method == 'POST' ? 201 : 200,
                );
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner';
      final session = _FleetSession(api)
        ..roleEnrolment = {'dashboardAccessible': true};
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: ProviderAssetsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drivers').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create Driver profile'));
      await tester.tap(find.text('Create Driver profile'));
      await tester.pumpAndSettle();
      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await enter('First name *', 'TEST_SAMPLE');
      await enter('Last name *', 'Created');
      await enter('Driver email (or phone required)', 'driver@example.invalid');
      await enter('Driving licence number *', 'TEST_LICENSE');
      tester
              .widget<TextFormField>(
                find.widgetWithText(
                  TextFormField,
                  'Licence expiry (YYYY-MM-DD) *',
                ),
              )
              .controller!
              .text =
          '2090-01-01';
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(created, true);
      expect(find.text('Driver onboarding'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(listReads, greaterThanOrEqualTo(2));
      expect(find.text('TEST_SAMPLE Created'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dispose();
    },
  );
}

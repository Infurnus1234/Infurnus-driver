import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';

class _FleetSession extends DriverSession {
  _FleetSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  testWidgets(
    'DA-03 & DA-04: driver form error is scoped to form and does not leak to drivers listing on cancel',
    (tester) async {
      final api =
          ApiService(
              client: MockClient((r) async {
                if (r.method == 'POST' &&
                    r.url.path == '/provider/managed-drivers') {
                  return http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {
                        'code': 'VALIDATION_ERROR',
                        'message': 'Licence number already registered in fleet',
                      },
                    }),
                    400,
                  );
                }
                final dynamic data = switch (r.url.path) {
                  '/partners/me' => {
                    'id': 'test-fleet',
                    'businessName': 'TEST_SAMPLE',
                    'approvalStatus': 'approved',
                  },
                  '/provider/earnings' ||
                  '/fleet/earnings' => <String, dynamic>{},
                  _ => <dynamic>[],
                };
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  200,
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
          child: MaterialApp(
            theme: Ops.theme,
            home: const ProviderAssetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Drivers tab
      await tester.tap(find.text('Drivers').last);
      await tester.pumpAndSettle();

      // Open Create Driver profile
      await tester.ensureVisible(find.text('Create Driver profile'));
      await tester.tap(find.text('Create Driver profile'));
      await tester.pumpAndSettle();

      // Fill in fields
      await tester.enterText(
        find.widgetWithText(TextFormField, 'First name *'),
        'John',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last name *'),
        'Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Driver email (or phone required)'),
        'john@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Driving licence number *'),
        'DL1234567890',
      );
      final expiryField = find.widgetWithText(
        TextFormField,
        'Licence expiry (YYYY-MM-DD) *',
      );
      tester.widget<TextFormField>(expiryField).controller!.text = '2030-01-01';

      // Submit form
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // DA-03: The specific error message from the backend is visible in the form
      expect(
        find.text('Licence number already registered in fleet'),
        findsOneWidget,
      );

      // Cancel / pop dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // DA-04: The error message must NOT leak or be visible on the Drivers listing screen
      expect(
        find.text('Licence number already registered in fleet'),
        findsNothing,
      );
      expect(
        find.textContaining('This request couldn\'t be completed'),
        findsNothing,
      );

      session.dispose();
      api.dispose();
    },
  );
}

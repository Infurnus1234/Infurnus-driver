import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';

import 'fleet_refresh_test.dart' show RefreshFixtureSession;

void main() {
  testWidgets(
    'reopening a vehicle code shows the same identity and never creates a vehicle',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final posts = <String>[];
      final api =
          ApiService(
              client: MockClient((r) async {
                if (r.method == 'POST') posts.add(r.url.path);
                final dynamic data = switch (r.url.path) {
                  '/partners/me' => {
                    'id': 'fleet',
                    'businessName': 'TEST Fleet',
                    'approvalStatus': 'approved',
                  },
                  '/fleet/vehicles' => [
                    {
                      'id': 'vehicle',
                      'make': 'Fixture',
                      'model': 'Cargo',
                      'plateNumber': 'TEST_ONLY',
                      'sector': 'logistics',
                      'category': 'mini_truck',
                      'verificationStatus': 'approved',
                      'isActive': true,
                      'vehicleCode': '001234',
                      'activeAssignmentCode': '001234',
                    },
                  ],
                  '/fleet/vehicles/vehicle/assignment-code' => {
                    'code': '001234',
                    'permanent': true,
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
      final session = RefreshFixtureSession(api)
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
      await tester.tap(find.text('Vehicles').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture Cargo'));
      await tester.pumpAndSettle();
      expect(find.text('Permanent vehicle code'), findsOneWidget);
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.ensureVisible(find.text('Show vehicle code'));
        await tester.tap(find.text('Show vehicle code'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Any eligible Driver in my Fleet'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('001234\nUse this same code'),
          findsOneWidget,
        );
        expect(find.textContaining('Expires:'), findsNothing);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
      expect(posts, [
        '/fleet/vehicles/vehicle/assignment-code',
        '/fleet/vehicles/vehicle/assignment-code',
      ]);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dispose();
    },
  );
}

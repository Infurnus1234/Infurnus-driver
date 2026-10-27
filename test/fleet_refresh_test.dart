import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';

class RefreshFixtureSession extends DriverSession {
  RefreshFixtureSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  testWidgets(
    'vehicle controls stay expanded during and after server refresh',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Completer<void>? pending;
      final api =
          ApiService(
              client: MockClient((r) async {
                if (r.url.path == '/partners/me' && pending != null) {
                  await pending.future;
                }
                final dynamic data = switch (r.url.path) {
                  '/partners/me' => {
                    'id': 'test-fleet',
                    'businessName': 'Test Fleet',
                    'approvalStatus': 'approved',
                  },
                  '/fleet/vehicles' => [
                    {
                      'id': 'test-vehicle',
                      'make': 'Fixture',
                      'model': 'Cargo',
                      'plateNumber': 'TEST_ONLY',
                      'sector': 'logistics',
                      'category': 'tata_407',
                      'verificationStatus': 'approved',
                      'isActive': false,
                      'activeAssignmentCode': '123456',
                    },
                  ],
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
      expect(find.text('ACTIVE'), findsOneWidget);
      pending = Completer<void>();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ACTIVE'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dispose();
    },
  );
}

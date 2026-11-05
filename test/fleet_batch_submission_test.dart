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
    'one Fleet action submits the batch and displays incomplete drafts without claiming approval',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bodies = <dynamic>[];
      final api =
          ApiService(
              client: MockClient((r) async {
                dynamic data;
                if (r.method == 'POST') {
                  expect(r.url.path, '/provider/approval-requests');
                  bodies.add(jsonDecode(r.body));
                  data = {
                    'requests': [
                      {'id': 'one'},
                      {'id': 'two'},
                      {'id': 'three'},
                    ],
                    'skipped': [
                      {
                        'targetType': 'driver_profile',
                        'reason': 'Upload the licence',
                      },
                    ],
                  };
                } else {
                  data = switch (r.url.path) {
                    '/partners/me' => {
                      'id': 'fleet',
                      'businessName': 'TEST Fleet',
                      'approvalStatus': 'pending',
                    },
                    '/provider/earnings' ||
                    '/fleet/earnings' => <String, dynamic>{},
                    _ => <dynamic>[],
                  };
                }
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
      await tester.tap(find.text('Submit Pending Requests'));
      await tester.pumpAndSettle();
      expect(bodies, [
        {'requestType': 'fleet_submission'},
      ]);
      expect(find.textContaining('3 pending requests'), findsOneWidget);
      expect(find.textContaining('independent Admin decision'), findsOneWidget);
      expect(find.textContaining('Upload the licence'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dispose();
    },
  );
}

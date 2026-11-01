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
  for (final contact in ['+919876543210', 'driver@example.invalid']) {
    testWidgets(
      'existing Driver invitation accepts $contact without creating another Driver',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final posts = <String>[];
        final bodies = <dynamic>[];
        final api =
            ApiService(
                client: MockClient((r) async {
                  dynamic data;
                  if (r.method == 'POST') {
                    posts.add(r.url.path);
                    bodies.add(jsonDecode(r.body));
                    data = {
                      'id': 'invitation',
                      'expiresAt': '2090-01-01T00:00:00Z',
                    };
                  } else {
                    data = switch (r.url.path) {
                      '/partners/me' => {
                        'id': 'fleet',
                        'businessName': 'TEST Fleet',
                        'approvalStatus': 'approved',
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
        await tester.tap(find.text('Drivers').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Invite an existing Driver'));
        await tester.tap(find.text('Invite an existing Driver'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Registered Driver phone (with country code) or email',
          ),
          contact,
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(posts, ['/provider/fleet-drivers']);
        expect(bodies, [
          {contact.contains('@') ? 'email' : 'phone': contact},
        ]);
        expect(
          find.textContaining('Profile > Fleet invitations'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.dispose();
      },
    );
  }
}

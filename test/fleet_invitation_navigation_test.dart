import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infurnus_driver/core/theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/screens/driver/fleet_invitations_screen.dart';

import 'profile_menu_and_bug_fixes_test.dart' show TestDriverSession;

void main() {
  testWidgets(
    'pending Driver reaches invitations from the real Profile menu and accepts management consent without approval',
    (tester) async {
      InfurnusTheme.isTesting = true;
      GoogleFonts.config.allowRuntimeFetching = false;
      var accepted = false;
      final posts = <String>[];
      final api =
          ApiService(
              client: MockClient((r) async {
                dynamic data;
                if (r.method == 'POST') {
                  posts.add(r.url.path);
                  accepted = true;
                  data = {'accepted': true, 'vehicleAssigned': false};
                } else if (r.url.path == '/provider/fleet-invitations') {
                  data = accepted
                      ? <dynamic>[]
                      : [
                          {
                            'id': 'test-invite',
                            'businessName': 'TEST Fleet',
                            'expiresAt': '2090-01-01',
                          },
                        ];
                } else {
                  data = <String, dynamic>{};
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  200,
                );
              }),
            )
            ..accessToken = 'test-token'
            ..userId = 'test-driver'
            ..role = 'driver'
            ..providerMode = 'driver';
      final session = TestDriverSession(api: api)
        ..profile = {'id': 'test-profile', 'verificationStatus': 'pending'}
        ..roleEnrolment = {
          'role': 'driver',
          'dashboardAccessible': false,
          'steps': ['licence'],
          'progress': {},
        };
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();
      appRouter.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Profile & Settings'), findsOneWidget);
      await tester.ensureVisible(find.text('Fleet invitations'));
      await tester.tap(find.text('Fleet invitations'));
      await tester.pumpAndSettle();
      expect(find.byType(FleetInvitationsScreen), findsOneWidget);
      expect(find.text('TEST Fleet'), findsOneWidget);
      expect(posts, isEmpty);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Allow Fleet profile management?'), findsOneWidget);
      expect(posts, isEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(posts, ['/provider/fleet-invitations/test-invite/accept']);
      expect(find.text('No pending Fleet invitations.'), findsOneWidget);
      expect(session.profile!['verificationStatus'], 'pending');
      expect(session.assignedVehicle, isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dispose();
    },
  );
}

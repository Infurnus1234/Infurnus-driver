import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/main.dart';
import 'package:infurnus_driver/providers/app_state.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/router/app_router.dart';

void main() {
  testWidgets(
    'signup entry, OTP and onboarding use real screens without dashboard bypass',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final profile = {
        'id': 'fixture-profile',
        'userId': 'fixture-user',
        'licenseNumber': 'fixture',
        'licenseExpiry': '2099-12-31',
        'verificationStatus': 'pending',
      };
      final api = ApiService(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          paths.add(r.url.path);
          dynamic data;
          switch (r.url.path) {
            case '/auth/signup':
              data = {'signupId': 'fixture-signup'};
            case '/auth/signup/verify':
              data = {
                'accessToken': 'fixture-token',
                'userId': 'fixture-user',
                'roleEnrolment': {
                  'role': 'driver',
                  'dashboardAccessible': false,
                  'steps': ['profile_photo', 'licence', 'finish'],
                  'progress': {},
                },
              };
            case '/rides/driver/profile':
              data = profile;
            case '/rides/driver/assigned-vehicle':
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'NO_ASSIGNED_VEHICLE',
                    'message': 'No assigned vehicle',
                  },
                }),
                404,
              );
            case '/provider/onboarding':
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'dashboardAccessible': false, 'deferred_codes': []},
                }),
                200,
              );
            case '/provider/document-requirements':
              data = [];
            case '/provider/approvals':
              data = [];
            case '/rides/driver/documents':
              data = [];
            case '/driver-applications':
              data = [];
            case '/partners/me':
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'PARTNER_NOT_FOUND',
                    'message': 'No owned partner',
                  },
                }),
                404,
              );
            case '/users/fixture-user':
              data = {
                'firstName': 'Fixture',
                'lastName': 'Driver',
                'email': 'driver@example.invalid',
              };
            default:
              fail('Unexpected protected driver request ${r.url.path}');
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': data,
              if (r.method == 'GET' && r.url.path == '/driver-applications')
                'pagination': {'page': 1, 'limit': 100, 'total': 0},
            }),
            200,
          );
        }),
      );
      final session = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppState()),
            ChangeNotifierProvider.value(value: session),
          ],
          child: const InfurnusApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      for (final legacy in [
        '/personal-details',
        '/profile-photo',
        '/document-upload',
      ]) {
        appRouter.go(legacy);
        await tester.pumpAndSettle();
        expect(find.text('How will you use INFURNUS?'), findsOneWidget);
        expect(find.text('Driving licence number *'), findsNothing);
      }
      appRouter.go('/login');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account with email or phone'));
      await tester.pumpAndSettle();
      expect(find.text('How will you use INFURNUS?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Select an account type to continue.'), findsOneWidget);
      await tester.tap(find.text('Driver'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      // Email/phone path: Google button is hidden, form is open directly
      expect(find.text('Sign up with Google'), findsNothing);
      expect(find.text('Use email/phone signup (OTP)'), findsNothing);
      const fields = {
        'First name *': 'Fixture',
        'Last name *': 'Driver',
        'Email (or phone required)': 'driver@example.invalid',
      };
      for (final entry in fields.entries) {
        final finder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.ensureVisible(finder);
        await tester.enterText(finder, entry.value);
      }
      expect(find.text('Driving licence number *'), findsNothing);
      expect(find.byIcon(Icons.upload_file), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Driving licence number *'), findsNothing);
      expect(find.text('Licence expiry (YYYY-MM-DD) *'), findsNothing);
      final send = find.text('Send account verification code');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Verify your account'), findsOneWidget);
      expect(session.authenticated, isFalse);
      // OTP screen: enter one digit per box (6 separate TextFields)
      final otpBoxes = find.byType(TextField);
      expect(otpBoxes.evaluate().length, 6);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(otpBoxes.at(i), '${i + 1}');
      }
      await tester.pump();
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Driver onboarding'), findsOneWidget);
      expect(find.text('Driver Dashboard'), findsNothing);
      expect(session.dashboardAllowed, isFalse);
      expect(find.text('Your profile photo'), findsOneWidget);
      expect(find.byType(Stepper), findsNothing);
      expect(
        find.text('Choose photo').evaluate().isNotEmpty
            ? find.text('Choose photo')
            : find.text('Choose source'),
        findsOneWidget,
      );

      expect(find.text('Driving licence number *'), findsNothing);
      await tester.tap(find.text('Upload & continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose one profile photo.'), findsOneWidget);
      expect(find.text('Your profile photo'), findsOneWidget);
      profile['verificationStatus'] = 'rejected';
      profile['rejectionReason'] = 'Licence image is unreadable';
      session.documents.add({
        'id': 'licence-doc',
        'documentType': 'driver_license',
        'status': 'rejected',
        'rejectionReason': 'Licence image is unreadable',
      });
      await session.refresh();
      appRouter.go('/verification-status');
      await tester.pumpAndSettle();
      expect(
        find.text('Verification summary', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.textContaining('Licence image is unreadable'), findsWidgets);
      expect(session.dashboardAllowed, isFalse);
      expect(
        paths,
        containsAll([
          '/auth/signup',
          '/auth/signup/verify',
          '/rides/driver/profile',
          '/provider/document-requirements',
        ]),
      );
      session.documents.add({
        'id': 'legacy-document',
        'documentType': 'other',
        'documentMetadata': {'documentCode': 'legacy_identity'},
        'verificationStatus': 'rejected',
      });
      appRouter.go('/onboarding?task=summary');
      await tester.pumpAndSettle();
      // A requested later task cannot skip the first missing photo.
      expect(find.text('Ready for review'), findsOneWidget);
      expect(find.text('legacy identity (optional)'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

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
        client: MockClient((r) async {
          paths.add(r.url.path);
          dynamic data;
          switch (r.url.path) {
            case '/auth/signup':
              data = {'signupId': 'fixture-signup'};
            case '/auth/signup/verify':
              data = {'accessToken': 'fixture-token', 'userId': 'fixture-user'};
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
      final session = DriverSession(api: api);
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
      expect(find.text('Sign in with Google'), findsOneWidget);
      await tester.tap(find.text('Create a Driver account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Continue'), findsNothing);
      await tester.tap(find.text('Use email/phone signup (OTP)'));
      await tester.pumpAndSettle();
      const fields = {
        'First name *': 'Fixture',
        'Last name *': 'Driver',
        'Email (or phone required)': 'driver@example.invalid',
        'Password *': 'fixture-password',
        'Confirm password *': 'fixture-password',
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
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      for (final entry in {
        'Driving licence number *': 'fixture',
        'Licence expiry (YYYY-MM-DD) *': '2099-12-31',
      }.entries) {
        final finder = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.enterText(finder, entry.value);
      }
      final send = find.text('Send account verification code');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('OTP Verification'), findsOneWidget);
      expect(session.authenticated, isFalse);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Driver onboarding'), findsOneWidget);
      expect(find.text('Driver Dashboard'), findsNothing);
      expect(session.dashboardAllowed, isFalse);
      await tester.ensureVisible(find.text('Personal details & licence'));
      await tester.tap(find.text('Personal details & licence'));
      await tester.pumpAndSettle();
      final licenceInput = find.widgetWithText(
        TextField,
        'Driving licence number *',
      );
      await tester.ensureVisible(licenceInput);
      await tester.enterText(licenceInput, 'TEST-INPUT-PRESERVED');
      final requestsWhileTyping = paths.length;
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(paths.length, requestsWhileTyping);
      expect(find.text('TEST-INPUT-PRESERVED'), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(paths.length, greaterThan(requestsWhileTyping));
      appRouter.go('/driver/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('Driver verification'), findsOneWidget);
      profile['verificationStatus'] = 'rejected';
      profile['rejectionReason'] = 'Licence image is unreadable';
      await session.refresh();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Licence image is unreadable'),
        findsOneWidget,
      );
      expect(find.text('Driver Dashboard'), findsNothing);
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
      appRouter.go('/onboarding');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('KYC & driver documents'));
      await tester.tap(find.text('KYC & driver documents'));
      await tester.pumpAndSettle();
      final legacy = find.text('legacy identity (optional)');
      expect(legacy, findsOneWidget);
      await tester.ensureVisible(legacy);
      final tile = find.ancestor(of: legacy, matching: find.byType(ListTile));
      await tester.tap(
        find.descendant(of: tile, matching: find.byIcon(Icons.upload_file)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload legacy identity'), findsOneWidget);
      expect(find.text('Add camera page'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vehicle documents'));
      await tester.tap(find.text('Vehicle documents'));
      await tester.pumpAndSettle();
      expect(find.text('Manage owned vehicle documents'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

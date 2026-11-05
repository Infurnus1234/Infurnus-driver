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

class _FleetSession extends DriverSession {
  _FleetSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  for (final contact in [
    'neither',
    'phone',
    'email',
    'both',
    'invalid-email',
    'invalid-phone',
  ]) {
    testWidgets(
      'managed Driver contact form validates $contact before provisioning',
      (tester) async {
        final posts = <Map<String, dynamic>>[];
        final api =
            ApiService(
                client: MockClient((r) async {
                  if (r.method == 'POST' &&
                      r.url.path == '/provider/managed-drivers') {
                    posts.add(
                      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
                    );
                    return http.Response(
                      jsonEncode({
                        'success': false,
                        'error': {
                          'code': 'TEST_STOP',
                          'message': 'Synthetic save stop',
                        },
                      }),
                      409,
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
        await tester.tap(find.text('Drivers').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Create Driver profile'));
        await tester.tap(find.text('Create Driver profile'));
        await tester.pumpAndSettle();
        Future<void> enter(String label, String text) async {
          final field = find.widgetWithText(TextFormField, label);
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
        }

        await enter('First name *', 'TEST_SAMPLE');
        await enter('Last name *', 'Contact');
        await enter('Driving licence number *', 'TEST-LICENCE');
        // CalendarField uses a read-only text field. Select a valid future date
        // via the public field's controller so this test focuses on contact validation.
        final expiry = find.widgetWithText(
          TextFormField,
          'Licence expiry (YYYY-MM-DD) *',
        );
        final date = DateTime.now().add(const Duration(days: 365));
        tester.widget<TextFormField>(expiry).controller!.text =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (['email', 'both', 'invalid-email'].contains(contact)) {
          await enter(
            'Driver email (or phone required)',
            contact == 'invalid-email' ? 'bad' : ' DRIVER@example.invalid ',
          );
        }
        if (['phone', 'both', 'invalid-phone'].contains(contact)) {
          await enter(
            'Phone with country code (or email required)',
            contact == 'invalid-phone' ? 'bad-number' : '+91 98765 43210',
          );
        }
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        if (['neither', 'invalid-email', 'invalid-phone'].contains(contact)) {
          expect(posts, isEmpty);
          expect(
            find.textContaining(
              contact == 'neither'
                  ? 'Phone number or email address is required'
                  : contact == 'invalid-email'
                  ? 'Enter a valid email'
                  : 'Enter a valid phone',
            ),
            findsWidgets,
          );
        } else {
          expect(posts, hasLength(1));
          expect(find.text('Create Driver profile'), findsOneWidget);
          expect(
            find.textContaining('Check your information and retry.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'First name *'),
                )
                .controller!
                .text,
            'TEST_SAMPLE',
          );
          if (contact != 'email') {
            expect(posts.single['phone'], '+919876543210');
          }
          if (contact != 'phone') {
            expect(posts.single['email'], 'driver@example.invalid');
          }
          if (contact == 'phone') {
            expect(posts.single.containsKey('email'), false);
          }
        }
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.dispose();
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/auth/login_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';

void main() {
  testWidgets(
    'Fleet credential rejection opens password guidance and blocks empty retry',
    (tester) async {
      final logins = <Map>[];
      final api = ApiService(
        client: MockClient((r) async {
          if (r.method == 'POST' && r.url.path == '/auth/login') {
            logins.add(jsonDecode(r.body) as Map);
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {
                  'code': 'INVALID_CREDENTIALS',
                  'message': 'Invalid email/phone or password',
                },
              }),
              401,
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'NOT_FOUND', 'message': 'Unavailable'},
            }),
            404,
          );
        }),
      );
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '9999999999');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Fleet Owner accounts need an account password'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Account password'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(logins, hasLength(1));
      expect(find.text('Enter your Fleet account password.'), findsOneWidget);
      expect(logins.single.containsKey('password'), isFalse);
    },
  );
}

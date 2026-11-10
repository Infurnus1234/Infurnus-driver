import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/common/bank_account_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'DA-11: Bank proof shows Not submitted and upload button when empty',
    (tester) async {
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/provider/bank-account') {
            return http.Response(
              jsonEncode({'success': true, 'data': null}),
              200,
            );
          }
          if (request.url.path == '/partners/me') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'partner-1'},
              }),
              200,
            );
          }
          if (request.url.path == '/partners/partner-1/documents') {
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      )..userId = 'driver-1';
      final session = DriverSession(api: api);
      addTearDown(session.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: BankAccountScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bank proof: Not submitted'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Upload bank proof'),
        findsOneWidget,
      );
      expect(find.textContaining("Couldn't load status"), findsNothing);
    },
  );

  testWidgets('DA-11: Bank proof shows error and retry when load fails', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path == '/provider/bank-account') {
          return http.Response(
            jsonEncode({'success': true, 'data': null}),
            200,
          );
        }
        if (request.url.path == '/partners/me') {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Server timeout'},
            }),
            500,
          );
        }
        return http.Response('{}', 200);
      }),
    )..userId = 'driver-1';
    final session = DriverSession(api: api);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: BankAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load status"), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(find.text('Bank proof: Not submitted'), findsNothing);
  });
}

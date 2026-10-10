import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/admin/provider_review_screen.dart';

http.Response envelope(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
String token(String role) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';

void main() {
  testWidgets(
    'reviewer UI refuses to fetch admin-only resources without an authorized session',
    (tester) async {
      final paths = <String>[];
      final session = DriverSession(
        api: ApiService(
          client: MockClient((r) async {
            paths.add(r.url.path);
            return envelope([]);
          }),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: ProviderReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths, isEmpty);
      expect(find.text('Reviewer authorization required.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'authorized review requires rejection reason and sends the exact backend target version',
    (tester) async {
      final calls = <http.Request>[];
      final session = DriverSession(
        api: ApiService(
          client: MockClient((r) async {
            calls.add(r);
            switch (r.url.path) {
              case '/auth/login/verify':
                return envelope({
                  'accessToken': token('admin'),
                  'userId': 'reviewer',
                });
              case '/users/reviewer':
                return envelope({
                  'id': 'reviewer',
                  'role': 'admin',
                  'status': 'active',
                });
              case '/provider-approvals':
                return envelope([
                  {
                    'id': 'request',
                    'request_type': 'driver_verification',
                    'target_type': 'driver_profile',
                    'status': 'PENDING',
                  },
                ]);
              case '/admin/drivers/applications':
                return envelope({'items': []});
              case '/provider-approvals/request':
                return envelope({
                  'request': {
                    'id': 'request',
                    'request_type': 'driver_verification',
                    'status': 'PENDING',
                  },
                  'target': {
                    'updated_at': '2026-10-08T01:02:03.123456+00:00',
                    'license_number': 'fixture',
                  },
                  'documents': [],
                });
              case '/provider-approvals/request/review':
                return envelope({'id': 'request', 'status': 'REJECTED'});
              default:
                fail('Unexpected reviewer API ${r.url.path}');
            }
          }),
        ),
      );
      session.challengeId = 'challenge';
      expect(await session.verify('123456'), isTrue);
      expect(session.landingPath, '/admin/dashboard');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: ProviderReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a rejection reason.'), findsOneWidget);
      expect(calls.where((r) => r.url.path.endsWith('/review')), isEmpty);
      await tester.enterText(find.byType(TextField), 'Unreadable licence');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      final review = calls.singleWhere((r) => r.url.path.endsWith('/review'));
      expect(jsonDecode(review.body), {
        'status': 'REJECTED',
        'expectedUpdatedAt': '2026-10-08T01:02:03.123456+00:00',
        'reason': 'Unreadable licence',
      });
      expect(review.headers['authorization'], startsWith('Bearer '));
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}

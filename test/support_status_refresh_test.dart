import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/common/support_tickets_screen.dart';

void main() {
  testWidgets(
    'driver ticket list and open detail reflect refreshed server statuses',
    (tester) async {
      var status = 'OPEN';
      final api = ApiService(
        client: MockClient((request) async {
          final ticket = {
            'id': 'ticket',
            'ticketNumber': 'INF-SUP-000001',
            'subject': 'Booking issue',
            'message': 'Complete issue description',
            'status': status,
          };
          return http.Response(
            jsonEncode({
              'success': true,
              'data': request.url.path.endsWith('/ticket') ? ticket : [ticket],
              'pagination': {'page': 1, 'pageSize': 25, 'hasNext': false},
            }),
            200,
          );
        }),
      );
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: SupportTicketsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('INF-SUP-000001 · OPEN'), findsOneWidget);
      status = 'RESOLVED';
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.textContaining('INF-SUP-000001 · RESOLVED'), findsOneWidget);
      await tester.tap(find.text('Booking issue'));
      await tester.pumpAndSettle();
      expect(find.text('Status: RESOLVED'), findsOneWidget);
      status = 'CLOSED';
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Status: CLOSED'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

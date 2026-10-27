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
  testWidgets('validates, persists through API and reloads a created ticket', (
    tester,
  ) async {
    final tickets = <Map<String, dynamic>>[];
    var posts = 0;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.method == 'POST') {
          posts++;
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          tickets.add({...body, 'ticketNumber': 'TCK-TEST', 'status': 'OPEN'});
          return http.Response(
            jsonEncode({'success': true, 'data': tickets.last}),
            201,
          );
        }
        expect(r.url.queryParameters['includePagination'], 'true');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': tickets,
            'pagination': {'page': 1, 'pageSize': 25, 'hasNext': false},
          }),
          200,
        );
      }),
    );
    final session = DriverSession(api: api);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: SupportTicketsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create ticket'));
    await tester.pumpAndSettle();
    expect(posts, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'Local issue');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'TEST_SAMPLE issue description',
    );
    await tester.tap(find.text('Create ticket'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('Local issue'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TCK-TEST'), findsOneWidget);
  });
  testWidgets('provider errors are visible and preserve entered text', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient(
        (r) async => r.method == 'POST'
            ? http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'message': 'Support unavailable'},
                }),
                503,
              )
            : http.Response(
                jsonEncode({
                  'success': true,
                  'data': [],
                  'pagination': {'page': 1, 'pageSize': 25, 'hasNext': false},
                }),
                200,
              ),
      ),
    );
    final session = DriverSession(api: api);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: SupportTicketsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Local issue');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'TEST_SAMPLE issue description',
    );
    await tester.tap(find.text('Create ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Support unavailable'), findsOneWidget);
    expect(find.text('Local issue'), findsOneWidget);
  });
}

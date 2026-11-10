import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/fleet_reports_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('DA-06: Export visible trips shows message when empty', (
    tester,
  ) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client);
    api.accessToken = 'test.jwt.token';
    final session = DriverSession(api: api);

    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: const MaterialApp(home: FleetReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final exportButton = find.widgetWithText(
      OutlinedButton,
      'Export visible trips',
    );
    expect(exportButton, findsOneWidget);

    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(
      find.text('No trips to export. Adjust your filters to include trips.'),
      findsOneWidget,
    );

    session.dispose();
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/fleet_revenue_screen.dart';
import 'package:infurnus_driver/screens/fleet/managed_driver_screen.dart';

Widget host(DriverSession session, Widget screen) =>
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: screen)),
      ),
    );
void main() {
  testWidgets(
    'Fleet revenue renders paid/refund totals and exact owned vehicle details',
    (tester) async {
      final paths = <String>[];
      final api =
          ApiService(
              client: MockClient((r) async {
                paths.add(r.url.path);
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {
                      'timeZone': 'Asia/Kolkata',
                      'summary': {
                        'todayRevenuePaise': '8015',
                        'monthRevenuePaise': '8015',
                        'netRevenuePaise': '8015',
                        'grossRevenuePaise': '10025',
                        'refundPaise': '2010',
                        'completedJobs': 1,
                      },
                      'vehicles': [
                        {
                          'vehicleId': 'fixture-vehicle',
                          'make': 'Fixture',
                          'model': 'Sedan',
                          'plateNumber': 'TEST ONLY',
                          'sector': 'passenger',
                          'category': 'sedan',
                          'completedJobs': 1,
                          'todayRevenuePaise': '8015',
                          'monthRevenuePaise': '8015',
                          'netRevenuePaise': '8015',
                        },
                      ],
                      'history': [
                        {
                          'kind': 'ride',
                          'earnedAt': '2026-10-22',
                          'netRevenuePaise': '8015',
                        },
                      ],
                    },
                  }),
                  200,
                );
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner'
            ..accessToken = 'fixture';
      final s = DriverSession(api: api);
      addTearDown(s.dispose);
      await tester.pumpWidget(host(s, const FleetRevenuePanel()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gross collected: ₹100.25'), findsOneWidget);
      expect(find.textContaining('Refunds: ₹20.10'), findsOneWidget);
      expect(find.textContaining('Fixture Sedan'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Fixture Sedan'));
      await tester.tap(find.textContaining('Fixture Sedan'));
      await tester.pumpAndSettle();
      expect(paths, contains('/fleet/vehicles/fixture-vehicle/revenue'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'managed Driver edits save licence details without granting approval',
    (tester) async {
      Map? patch;
      final api =
          ApiService(
              client: MockClient((r) async {
                if (r.method == 'PATCH') {
                  patch = jsonDecode(r.body) as Map;
                  return http.Response(
                    jsonEncode({'success': true, 'data': {}}),
                    200,
                  );
                }
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {
                      'profile': {
                        'firstName': 'Fixture',
                        'lastName': 'Driver',
                        'verificationStatus': 'pending',
                        'licenseNumber': 'TEST-LICENCE',
                        'licenseExpiry': '2090-01-01',
                      },
                      'requirements': [],
                      'documents': [],
                    },
                  }),
                  200,
                );
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner'
            ..accessToken = 'fixture';
      final s = DriverSession(api: api);
      addTearDown(s.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: s,
          child: const MaterialApp(
            home: ManagedDriverScreen(userId: 'fixture-driver'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verification: pending'), findsOneWidget);
      await tester.tap(find.text('Edit licence details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'TEST-UPDATED');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(patch, {
        'licenseNumber': 'TEST-UPDATED',
        'licenseExpiry': '2090-01-01',
      });
      expect(find.text('Verification: pending'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/fleet_revenue_screen.dart';

Map<String, dynamic> report({String? vehicle}) {
  final rows = [
    for (var i = 1; i <= 4; i++)
      {
        'vehicleId': 'vehicle-$i',
        'plateNumber': 'TEST $i',
        'make': 'Fixture',
        'model': 'Sedan',
        'active': true,
        'completedTrips': i,
        'grossFarePaise': '${i * 10000}',
        'collectedAfterRefundsPaise': '${i * 8000}',
        'assignedDriverId': null,
      },
  ];
  return {
    'analytics': {
      'timeZone': 'Asia/Kolkata',
      'period': {'from': '2026-10-01', 'to': '2026-10-23'},
      'inventory': {
        'total': vehicle == null ? 4 : 1,
        'active': vehicle == null ? 4 : 1,
        'inactive': 0,
        'operating': 0,
      },
      'summary': {
        'completedTrips': vehicle == null ? 10 : 1,
        'cancelledTrips': 0,
        'totalJobs': 1,
        'grossFarePaise': '100000',
        'missingFareTrips': 0,
        'capturedPaise': '80000',
        'refundPaise': '1000',
        'collectedAfterRefundsPaise': '79000',
        'recordedRideCommissionPaise': '10000',
        'commissionCoveredTrips': 4,
        'pendingAttemptPaise': '2000',
        'failedAttemptPaise': '1000',
        'averageGrossFarePaise': '10000',
        'ownerNetEarningsPaise': null,
        'settledPaise': null,
        'knownDistanceMeters': null,
        'distanceCoveredTrips': 0,
        'knownOperatingSeconds': null,
        'timeCoveredTrips': 0,
        'completedToday': 0,
        'completedThisWeek': 1,
        'completedThisMonth': 10,
        'averageTripsPerVehicle': 2.5,
        'cancellationRatePercent': '0',
      },
      'status': [
        {'status': 'completed', 'count': 10},
      ],
      'vehicles': vehicle == null
          ? rows
          : rows.where((v) => v['vehicleId'] == vehicle).toList(),
      'history': [],
      'trends': [],
      'pagination': {
        'limit': 25,
        'vehicles': {'offset': 0, 'total': vehicle == null ? 4 : 1},
        'history': {'offset': 0, 'total': 0},
        'trends': {'offset': 0, 'total': 0},
      },
      'availability': {
        'ownerNetEarnings': 'Unavailable: no vehicle allocation.',
      },
    },
  };
}

Future<void> mount(
  WidgetTester tester,
  ApiService api, {
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session = DriverSession(api: api);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: FleetRevenuePanel(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'fleet and individual selection preserve period and fetch independent backend reports',
    (tester) async {
      final calls = <Uri>[];
      final api = ApiService(
        client: MockClient((r) async {
          calls.add(r.url);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': report(
                vehicle: r.url.path.contains('/vehicles/')
                    ? r.url.path.split('/')[3]
                    : null,
              ),
            }),
            200,
          );
        }),
      );
      await mount(tester, api);
      expect(find.text('Completed trips / jobs: 10'), findsOneWidget);
      expect(calls, hasLength(1));
      await tester.tap(find.byKey(const Key('analytics-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month').last);
      await tester.pumpAndSettle();
      expect(calls.last.queryParameters['period'], 'this_month');
      await tester.tap(find.byKey(const Key('analytics-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST 1').last);
      await tester.pumpAndSettle();
      expect(calls.last.path, '/fleet/vehicles/vehicle-1/revenue');
      expect(calls.last.queryParameters['period'], 'this_month');
      expect(find.text('Completed trips / jobs: 1'), findsOneWidget);
      expect(find.text('Completed trips / jobs: 10'), findsNothing);
      await tester.tap(find.byKey(const Key('analytics-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All vehicles').last);
      await tester.pumpAndSettle();
      expect(calls.last.path, '/fleet/revenue');
      expect(calls.last.queryParameters['period'], 'this_month');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'financial labels keep gross, captured and unavailable owner net distinct at narrow width',
    (tester) async {
      final api = ApiService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'success': true, 'data': report()}),
            200,
          ),
        ),
      );
      await mount(tester, api, width: 320);
      expect(
        find.textContaining('Known gross completed trip fares:'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Captured customer payments:'),
        findsOneWidget,
      );
      expect(
        find.text('Fleet Owner net earnings: Unavailable'),
        findsOneWidget,
      );
      expect(find.text('Settled to owner: Unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed analytics exposes retry and renders only a successful server response',
    (tester) async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((r) async {
          calls++;
          return calls == 1
              ? http.Response(
                  jsonEncode({
                    'success': false,
                    'error': {'code': 'TEMPORARY', 'message': 'Try again'},
                  }),
                  503,
                )
              : http.Response(
                  jsonEncode({'success': true, 'data': report()}),
                  200,
                );
        }),
      );
      await mount(tester, api);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Completed trips / jobs: 10'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Completed trips / jobs: 10'), findsOneWidget);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/core/operations_theme.dart';

class EmptyFleetSession extends DriverSession {
  EmptyFleetSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  testWidgets(
    'a Fleet Owner who skipped setup reaches the actual empty Fleet dashboard without creating records',
    (tester) async {
      final requests = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          if (r.url.path == '/partners/me') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'PARTNER_NOT_FOUND'},
              }),
              404,
            );
          }
          final dynamic data = switch (r.url.path) {
            '/provider/approvals' ||
            '/provider/document-requirements' ||
            '/provider/fleet-drivers' => [],
            '/provider/earnings' => {
              'days': [],
              'periods': [],
              'performance': [],
            },
            '/fleet/earnings' => {'thisMonthRevenue': 0, 'totalTrips': 0},
            _ => throw StateError(
              'Unexpected empty Fleet request ${r.url.path}',
            ),
          };
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      api.role = 'fleet_owner';
      api.providerMode = 'fleet_owner';
      api.userId = 'fixture-owner';
      final s = EmptyFleetSession(api);
      s.roleEnrolment = {'completed': true, 'dashboardAccessible': true};
      s.account = {'firstName': 'Fixture', 'lastName': 'Owner'};
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: s,
          child: MaterialApp(
            theme: Ops.theme,
            home: const ProviderAssetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fleet Overview'), findsOneWidget);
      expect(find.text('Total Vehicles'), findsOneWidget);
      expect(find.text('Total Drivers'), findsOneWidget);
      expect(find.text('Provider setup'), findsNothing);
      expect(find.text('Driver Mode'), findsNothing);
      expect(requests.every((r) => r.startsWith('GET ')), true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}

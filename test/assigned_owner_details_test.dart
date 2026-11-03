import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/widgets/assigned_vehicle_card.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/providers/driver_session.dart';

class _AssignmentApi extends ApiService {
  _AssignmentApi(http.Client client) : super(client: client);
  @override
  bool get roleFlowEnabled => false;
}

void main() {
  test('confirmed unassignment clears stale owner even if a later refresh request fails', () async {
    final api =
        _AssignmentApi(
            MockClient((r) async {
              if (r.url.path == '/rides/driver/profile') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {'id': 'profile'},
                  }),
                  200,
                );
              }
              if (r.url.path == '/rides/driver/assigned-vehicle') {
                return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'NO_ASSIGNED_VEHICLE',
                      'message': 'No active vehicle assigned',
                    },
                  }),
                  404,
                );
              }
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'UNAVAILABLE',
                    'message': 'Document service unavailable',
                  },
                }),
                503,
              );
            }),
          )
          ..accessToken = 'test-token'
          ..role = 'driver'
          ..userId = 'fixture';
    final session =
        DriverSession(api: api, onboardingDraftStore: MemorySessionStore())
          ..assignedVehicle = {
            'id': 'old',
            'owner': {'name': 'Old Owner'},
          };
    expect(await session.refresh(), false);
    expect(session.assignedVehicle, isNull);
    session.dispose();
    api.dispose();
  });
  testWidgets(
    'assigned vehicle displays live owner fields and clears them on unassignment',
    (tester) async {
      Future<void> show(Map<String, dynamic>? vehicle) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignedVehicleCard(
              vehicle: vehicle,
              loading: false,
              canManage: false,
              retry: () {},
            ),
          ),
        ),
      );
      final owner = {
        'name': 'Current Owner',
        'phone': '+919876543210',
        'email': 'owner@example.invalid',
        'businessName': 'Current Fleet',
        'businessType': 'Transport',
      };
      await show({'id': 'first', 'plateNumber': 'TEST_ONE', 'owner': owner});
      expect(find.text('Fleet Owner: Current Owner'), findsOneWidget);
      expect(find.text('Phone: +919876543210'), findsOneWidget);
      expect(find.text('Email: owner@example.invalid'), findsOneWidget);
      expect(find.text('Business: Current Fleet'), findsOneWidget);
      await show({
        'id': 'second',
        'plateNumber': 'TEST_TWO',
        'owner': {...owner, 'name': 'Updated Owner'},
      });
      expect(find.text('TEST_ONE'), findsNothing);
      expect(find.text('Fleet Owner: Current Owner'), findsNothing);
      expect(find.text('Fleet Owner: Updated Owner'), findsOneWidget);
      await show(null);
      expect(find.text('TEST_TWO'), findsNothing);
      expect(find.textContaining('Updated Owner'), findsNothing);
      expect(find.textContaining('owner@example.invalid'), findsNothing);
      expect(find.textContaining('Unassigned'), findsOneWidget);
    },
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/guided_provider_setup.dart';
import 'package:infurnus_driver/services/api_service.dart';

import 'guided_onboarding_test.dart' show image, pick;

void main() {
  testWidgets(
    'fleet business policy shows one document and confirms submission before business review',
    (tester) async {
      final documents = <Map<String, dynamic>>[];
      final requests = <String>[];
      var fail = true;
      final api =
          ApiService(
              client: MockClient((r) async {
                requests.add('${r.method} ${r.url.path}');
                dynamic data;
                switch (r.url.path) {
                  case '/partners/me':
                    data = {
                      'id': 'fixture-partner',
                      'businessName': 'Fixture business',
                      'approvalStatus': 'PENDING',
                    };
                  case '/partners/fixture-partner/documents':
                    data = documents;
                  case '/provider/approvals':
                    data = [];
                  case '/provider/onboarding':
                    return http.Response(
                      jsonEncode({
                        'success': true,
                        'data': {
                          'dashboardAccessible': false,
                          'deferred_codes': [],
                        },
                      }),
                      200,
                    );
                  case '/provider/document-requirements':
                    data = [
                      {
                        'document_code': 'pan',
                        'required': true,
                        'requires_expiry': false,
                        'minimum_pages': 1,
                      },
                    ];
                  case '/fleet/vehicles':
                    data = [];
                  case '/provider/earnings':
                    data = {};
                  case '/partners/fixture-partner/documents/upload':
                    if (fail) {
                      return http.Response(
                        jsonEncode({
                          'success': false,
                          'error': {
                            'code': 'FIXTURE_UPLOAD_FAILURE',
                            'message': 'Fixture upload failed',
                          },
                        }),
                        503,
                      );
                    }
                    documents.add({
                      'id': 'fixture-doc',
                      'documentType': 'PAN',
                      'status': 'DRAFT',
                      'metadata': {},
                    });
                    data = documents.last;
                  case '/partners/fixture-partner/documents/fixture-doc':
                    expect(jsonDecode(r.body)['status'], 'SUBMITTED');
                    documents.last['status'] = 'SUBMITTED';
                    data = documents.last;
                  case '/provider/approval-requests':
                    data = {'id': 'fixture-review', 'status': 'PENDING'};
                  default:
                    throw StateError(
                      'Unexpected fixture request ${r.url.path}',
                    );
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  200,
                );
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner'
            ..userId = 'fixture-owner'
            ..accessToken = 'fixture-token';
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            theme: Ops.theme,
            home: GuidedProviderSetup(picker: (_, _) async => [image]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pan'), findsOneWidget);
      expect(find.text('Driving licence number *'), findsNothing);
      expect(find.text('Add vehicle'), findsNothing);
      await pick(tester, 'Choose from gallery');
      Future<void> upload() async {
        await tester.scrollUntilVisible(
          find.text('Upload & continue'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Upload & continue'));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
      }

      await upload();
      await tester.scrollUntilVisible(
        find.text('Fixture upload failed'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Fixture upload failed'), findsOneWidget);
      expect(documents, isEmpty);
      expect(documents, isEmpty);
      fail = false;
      await upload();
      expect(documents.single['status'], 'SUBMITTED');
      expect(find.text('Business review'), findsOneWidget);
      expect(find.text('Submitted for review'), findsOneWidget);
      expect(
        requests.where((r) => r == 'POST /provider/approval-requests'),
        hasLength(1),
      );
      expect(find.text('Add vehicle'), findsNothing);
    },
  );
  testWidgets(
    'approved fleet creates a vehicle with server confirmation and category document substep',
    (tester) async {
      final vehicles = <Map<String, dynamic>>[];
      var failCreate = true, creations = 0;
      final api =
          ApiService(
              client: MockClient((r) async {
                dynamic data;
                switch (r.url.path) {
                  case '/partners/me':
                    data = {
                      'id': 'fixture-partner',
                      'businessName': 'Fixture fleet',
                      'approvalStatus': 'APPROVED',
                    };
                  case '/partners/fixture-partner/documents':
                    data = [];
                  case '/provider/approvals':
                    data = [];
                  case '/provider/onboarding':
                    return http.Response(
                      jsonEncode({
                        'success': true,
                        'data': {
                          'dashboardAccessible': false,
                          'deferred_codes': [],
                        },
                      }),
                      200,
                    );
                  case '/provider/document-requirements':
                    data = r.url.queryParameters['category'] == 'VAN'
                        ? [
                            {
                              'document_code': 'vehicle_rc',
                              'required': true,
                              'requires_expiry': false,
                              'minimum_pages': 1,
                            },
                          ]
                        : [];
                  case '/provider/earnings':
                    data = {};
                  case '/fleet/drivers':
                    data = [];
                  case '/provider/tracking':
                    data = [];
                  case '/fleet/vehicles':
                    if (r.method == 'POST') {
                      creations++;
                      if (failCreate) {
                        return http.Response(
                          jsonEncode({
                            'success': false,
                            'error': {
                              'code': 'DUPLICATE_VEHICLE',
                              'message': 'Fixture registration conflict',
                            },
                          }),
                          409,
                        );
                      }
                      final body = jsonDecode(r.body) as Map;
                      expect(body['sector'], 'logistics');
                      expect(body.containsKey('approvalStatus'), isFalse);
                      vehicles.add({
                        'id': 'fixture-vehicle',
                        ...body,
                        'approvalStatus': 'PENDING',
                      });
                      data = vehicles.last;
                    } else {
                      data = vehicles;
                    }
                  default:
                    throw StateError(
                      'Unexpected vehicle fixture ${r.url.path}',
                    );
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  200,
                );
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner'
            ..userId = 'fixture-owner'
            ..accessToken = 'fixture-token';
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            theme: Ops.theme,
            home: GuidedProviderSetup(picker: (_, _) async => [image]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> add() async {
        await tester.scrollUntilVisible(
          find.text('Add vehicle'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add vehicle'));
        await tester.pumpAndSettle();
      }

      await add();
      expect(creations, 0);
      for (final entry in {
        'Make *': 'Fixture',
        'Model *': 'Fixture van',
        'Registration / plate number *': 'FIXTURE-123',
        'Category *': 'VAN',
      }.entries) {
        final finder = find.widgetWithText(TextField, entry.key);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.enterText(finder, entry.value);
      }
      await add();
      expect(vehicles, isEmpty);
      expect(find.text('Fixture registration conflict'), findsOneWidget);
      failCreate = false;
      await add();
      expect(vehicles, hasLength(1));
      expect(creations, 2);
      await tester.scrollUntilVisible(
        find.text('Documents'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(find.text('vehicle rc'), findsOneWidget);
      expect(find.text('Model *'), findsNothing);
      expect(find.text('Choose source'), findsOneWidget);
    },
  );
}

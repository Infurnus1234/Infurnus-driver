import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/screens/auth/role_onboarding_screen.dart';
import 'package:infurnus_driver/screens/common/support_tickets_screen.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/screens/fleet/guided_provider_setup.dart';

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

class DetailsSession extends DriverSession {
  DetailsSession() {
    api.userId = 'fixture-owner';
    account = {'firstName': 'Saved', 'lastName': 'Driver'};
    roleEnrolment = {
      'steps': ['licence', 'profile_photo', 'details'],
      'progress': {'licence': 'skipped', 'profile_photo': 'skipped'},
    };
  }
  @override
  bool get authenticated => true;
}

class AssetsSession extends DriverSession {
  AssetsSession(ApiService api) : super(api: api) {
    roleEnrolment = {'dashboardAccessible': true};
  }
  @override
  bool get authenticated => true;
}

class RoleFlowApi extends ApiService {
  RoleFlowApi(http.Client client, SessionStore store)
    : super(client: client, store: store);
  @override
  bool get roleFlowEnabled => true;
}

void main() {
  testWidgets(
    'FLEET-04 approved vehicle DTO does not restart document review',
    (tester) async {
      final paths = <String>[];
      final api =
          ApiService(
              client: MockClient((r) async {
                paths.add(r.url.toString());
                switch (r.url.path) {
                  case '/partners/me':
                    return ok({
                      'id': 'fixture-partner',
                      'businessName': 'Saved business',
                      'approvalStatus': 'approved',
                    });
                  case '/fleet/vehicles':
                    return ok([
                      {
                        'id': 'approved',
                        'verificationStatus': 'approved',
                        'category': 'sedan',
                        'isActive': true,
                      },
                    ]);
                  case '/fleet/drivers':
                    return ok([]);
                  case '/provider/earnings':
                    return ok({});
                  default:
                    return ok([]);
                }
              }),
            )
            ..role = 'fleet_owner'
            ..providerMode = 'fleet_owner'
            ..userId = 'fixture';
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: GuidedProviderSetup()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add an owned vehicle'), findsOneWidget);
      expect(paths.where((x) => x.contains('category=sedan')), isEmpty);
      expect(find.text('Vehicle review'), findsNothing);
    },
  );
  for (final remember in [false, true]) {
    testWidgets(
      'AUTH-01 retry revalidates a pending session; remember=$remember',
      (tester) async {
        var unavailable = true;
        var refreshes = 0;
        final store = MemorySessionStore();
        final token =
            'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'fleet_owner'})))}.x';
        final api = RoleFlowApi(
          MockClient((r) async {
            if (r.url.path == '/auth/google') {
              return ok({'userId': 'fixture', 'accessToken': token});
            }
            if (r.url.path == '/auth/refresh') {
              refreshes++;
              return ok({'accessToken': token});
            }
            if (r.url.path == '/provider/enrolment') {
              if (unavailable) {
                return http.Response(
                  jsonEncode({
                    'error': {'message': 'Unavailable'},
                  }),
                  503,
                );
              }
              return ok({
                'role': 'fleet_owner',
                'dashboardAccessible': false,
                'steps': ['business', 'driver', 'vehicle'],
                'progress': {},
              });
            }
            return ok({'firstName': 'Fixture', 'lastName': 'Owner'});
          }),
          store,
        )..rememberMe = remember;
        final session = DriverSession(
          api: api,
          onboardingDraftStore: MemorySessionStore(),
        );
        expect(await session.authenticateGoogle('fixture'), false);
        expect(session.authenticated, false);
        expect(session.restorationNeedsRetry, true);
        expect(store.value, remember ? isNotNull : isNull);
        unavailable = false;
        expect(await session.restore(), true);
        expect(refreshes, 1);
        expect(session.authenticated, true);
        expect(session.restorationNeedsRetry, false);
        expect(session.account?['firstName'], 'Fixture');
        expect(store.value, remember ? isNotNull : isNull);
        session.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final status in [401, 403]) {
    test('AUTH-01 provider denial $status clears credentials', () async {
      final store = MemorySessionStore();
      final token =
          'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'fleet_owner'})))}.x';
      final api = ApiService(
        store: store,
        client: MockClient((r) async {
          if (r.url.path == '/auth/google') {
            return ok({'userId': 'fixture', 'accessToken': token});
          }
          return http.Response(
            jsonEncode({
              'error': {'message': 'Forbidden'},
            }),
            status,
          );
        }),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.authenticateGoogle('fixture'),
        throwsA(isA<ApiException>()),
      );
      expect(api.accessToken, isNull);
      expect(store.value, isNull);
    });
  }
  testWidgets(
    'ONB-01 restores names and requires valid details before submission',
    (tester) async {
      final session = DetailsSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: RoleOnboardingScreen()),
        ),
      );
      await tester.pump();
      final inputs = find.byType(TextField);
      expect(tester.widget<TextField>(inputs.at(0)).controller!.text, 'Saved');
      expect(tester.widget<TextField>(inputs.at(1)).controller!.text, 'Driver');
      await tester.enterText(inputs.at(0), 'Unsaved draft');
      session.notifyListeners();
      await tester.pump();
      expect(
        tester.widget<TextField>(inputs.at(0)).controller!.text,
        'Unsaved draft',
      );
      await tester.enterText(inputs.at(0), ' ');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save details & continue'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'ONB-01 explicit edit step shows its own index rather than completed count',
    (tester) async {
      final session = DetailsSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(
            home: RoleOnboardingScreen(editStep: 'licence'),
          ),
        ),
      );
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
    },
  );
  for (final status in [429, 503]) {
    test(
      'AUTH-01 $status after verified Google response preserves recoverable session',
      () async {
        final store = MemorySessionStore();
        final api = ApiService(
          store: store,
          client: MockClient((r) async {
            if (r.url.path == '/auth/google') {
              return ok({
                'userId': 'fixture-driver',
                'accessToken':
                    'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver'})))}.x',
                'csrfToken': 'fixture-csrf',
              });
            }
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': 'Temporary failure'},
              }),
              status,
            );
          }),
        );
        addTearDown(api.dispose);
        await expectLater(
          api.authenticateGoogle('fixture'),
          throwsA(isA<ApiException>()),
        );
        expect(api.accessToken, isNotNull);
        expect(store.value, isNotNull);
      },
    );
  }
  testWidgets(
    'SUP-01 failed next-page fetch keeps current page and allows retry',
    (tester) async {
      var failNext = true;
      final api = ApiService(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          final page = int.parse(r.url.queryParameters['page'] ?? '1');
          if (page == 2 && failNext) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'Temporary page failure'},
              }),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': List.generate(
                page == 1 ? 25 : 1,
                (i) => {
                  'id': 'ticket-$page-$i',
                  'subject': 'Page $page ticket $i',
                  'message': 'Fixture message',
                  'ticketNumber': 'TEST-$i',
                  'status': 'OPEN',
                },
              ),
              'pagination': {
                'page': page,
                'pageSize': 25,
                'hasNext': page == 1,
              },
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
      await tester.scrollUntilVisible(
        find.text('Next'),
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Page 1'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsNothing);
      failNext = false;
      await tester.scrollUntilVisible(
        find.text('Retry'),
        -600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2'), findsOneWidget);
    },
  );

  for (final fleet in [false, true]) {
    testWidgets(
      'FLEET-01/02/03 pending ${fleet ? 'Fleet' : 'Driver'} business allows draft vehicles and keeps operational gates',
      (tester) async {
        final calls = <String>[];
        final api =
            ApiService(
                store: MemorySessionStore(),
                client: MockClient((r) async {
                  calls.add(r.url.path);
                  switch (r.url.path) {
                    case '/partners/me':
                      return ok({
                        'id': 'fixture-partner',
                        'businessName': 'Fixture business',
                        'approvalStatus': 'pending',
                      });
                    case '/fleet/vehicles':
                    case '/partners/vehicles':
                      return ok([
                        {
                          'id': 'approved-active',
                          'make': 'Active',
                          'model': 'Car',
                          'plateNumber': 'FIXTURE1',
                          'isActive': true,
                          'verificationStatus': 'approved',
                          'sector': 'passenger',
                          'category': 'sedan',
                        },
                        {
                          'id': 'inactive',
                          'make': 'Inactive',
                          'model': 'Car',
                          'plateNumber': 'FIXTURE2',
                          'isActive': false,
                          'verificationStatus': 'pending',
                          'sector': 'passenger',
                          'category': 'sedan',
                        },
                      ]);
                    case '/provider/earnings':
                    case '/fleet/earnings':
                      return ok({});
                    default:
                      return ok([]);
                  }
                }),
              )
              ..userId = 'fixture-owner'
              ..role = fleet ? 'fleet_owner' : 'driver'
              ..providerMode = fleet ? 'fleet_owner' : 'driver';
        final session = AssetsSession(api);
        addTearDown(session.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: const MaterialApp(home: ProviderAssetsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        if (fleet) {
          await tester.tap(find.text('Vehicles').last);
          await tester.pumpAndSettle();
        }
        final add = find.text('Add vehicle');
        await tester.ensureVisible(add);
        expect(
          tester
              .widget<FilledButton>(
                find
                    .ancestor(
                      of: add,
                      matching: find.byWidgetPredicate(
                        (w) => w is FilledButton,
                      ),
                    )
                    .first,
              )
              .onPressed,
          isNotNull,
        );
        await tester.ensureVisible(find.text('Active', skipOffstage: false));
        await tester.tap(find.text('Active'));
        await tester.pumpAndSettle();
        expect(find.text('Active Car'), findsOneWidget);
        expect(find.text('Inactive Car'), findsNothing);
        await tester.tap(find.text('Inactive'));
        await tester.pumpAndSettle();
        expect(find.text('Active Car'), findsNothing);
        expect(find.text('Inactive Car'), findsOneWidget);
        if (fleet) {
          await tester.tap(find.text('Drivers').last);
          await tester.pumpAndSettle();
          final create = find.text('Create Driver profile');
          await tester.ensureVisible(create);
          await tester.tap(create);
          await tester.pumpAndSettle();
          expect(find.text('Business approval required'), findsOneWidget);
          expect(calls, isNot(contains('/provider/managed-drivers')));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('AUTH-03 remember-me false never persists an authenticated credential', () async {
    final store = MemorySessionStore();
    final api = ApiService(
      store: store,
      client: MockClient((r) async {
        if (r.url.path == '/auth/google') {
          return ok({
            'userId': 'fixture',
            'accessToken':
                'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver'})))}.x',
          });
        }
        return ok({'id': 'fixture-profile'});
      }),
    )..rememberMe = false;
    addTearDown(api.dispose);
    await api.authenticateGoogle('fixture');
    expect(api.accessToken, isNotNull);
    expect(store.value, isNull);
  });
}

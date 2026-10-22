import 'support/golden_fonts.dart';

import 'package:infurnus_driver/screens/auth/role_selection_screen.dart';

import 'guided_onboarding_test.dart' show FixtureSession;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/screens/auth/role_onboarding_screen.dart';
import 'package:infurnus_driver/core/operations_theme.dart';

class RoleApi extends ApiService {
  RoleApi(http.Client client)
    : super(client: client, store: MemorySessionStore());
  @override
  bool get roleFlowEnabled => true;
}

void main() {
  test('only an existing authenticated trip remains visible before new onboarding is complete', () {
    final s = FixtureSession();
    s.roleEnrolment = {'dashboardAccessible': false};
    expect(s.landingPath, '/role-onboarding');
    expect(s.dashboardAllowed, false);
    s.currentTrip = {'id': 'fixture-existing-trip', 'status': 'in_progress'};
    expect(s.landingPath, '/driver/active-trip');
    expect(s.dashboardAllowed, true);
    expect(s.operationalAllowed, false);
    s.currentTrip = null;
    expect(s.landingPath, '/role-onboarding');
    expect(s.dashboardAllowed, false);
    s.dispose();
  });
  test('Google authentication retains its session when loading the next onboarding step fails', () async {
    final store = MemorySessionStore();
    final api = RoleApi(
      MockClient((r) async {
        if (r.url.path == '/auth/google') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'userId': 'fixture-user',
                'accessToken': 'fixture-token',
              },
            }),
            200,
          );
        }
        if (r.url.path == '/rides/driver/profile') {
          return http.Response(
            jsonEncode({
              'error': {'code': 'DRIVER_PROFILE_NOT_FOUND'},
            }),
            404,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'message': 'Fixture unavailable'},
          }),
          503,
        );
      }),
    );
    final s = DriverSession(api: api, onboardingDraftStore: store);
    expect(await s.authenticateGoogle('fixture', signup: true), false);
    expect(s.authenticated, true);
    expect(api.accessToken, 'fixture-token');
    expect(s.restorationNeedsRetry, true);
    s.dispose();
  });
  setUpAll(() async {
    await loadGoldenFonts();
  });

  for (final role in ['driver', 'driver_fleet_owner', 'fleet_owner']) {
    testWidgets('$role resumes its exact persisted optional-step sequence', (
      tester,
    ) async {
      var verified = false,
          completed = false,
          rolePending = true,
          deferred = false;
      final progress = <String, String>{}, writes = <String>[];
      final steps = role == 'driver'
          ? ['vehicle_assignment', 'profile_photo']
          : role == 'fleet_owner'
          ? ['business', 'driver', 'vehicle']
          : ['licence', 'profile_photo', 'details'];
      Map<String, dynamic> state() => {
        'role': rolePending ? 'driver' : role,
        'steps': rolePending ? ['vehicle_assignment', 'profile_photo'] : steps,
        'progress': progress,
        'codeVerified': verified,
        'completed': completed,
        'dashboardAccessible': completed || deferred,
        'assignmentStatus': 'unassigned',
        'roleSelectionPending': rolePending,
      };
      http.Response ok(dynamic value) =>
          http.Response(jsonEncode({'success': true, 'data': value}), 200);
      final api = RoleApi(
        MockClient((r) async {
          if (r.url.path == '/auth/google') {
            expect(
              (jsonDecode(r.body) as Map).containsKey('providerRole'),
              false,
            );
            return ok({
              'userId': 'fixture-user',
              'accessToken':
                  'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver'})))}.x',
            });
          }
          if (r.url.path == '/provider/enrolment/role') {
            expect(jsonDecode(r.body)['role'], role);
            rolePending = false;
            writes.add('role');
            return ok({
              'role': role,
              'accessToken':
                  'x.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.x',
            });
          }
          if (r.url.path == '/users/fixture-user') {
            return ok({
              'role': rolePending ? 'driver' : role,
              'status': 'active',
            });
          }
          if (r.url.path == '/rides/driver/profile') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'DRIVER_PROFILE_NOT_FOUND'},
              }),
              404,
            );
          }
          if (r.url.path == '/provider/enrolment/verify-code') {
            writes.add('code');
            if (jsonDecode(r.body)['code'] != 'ABCDEF123456') {
              return http.Response(
                jsonEncode({
                  'error': {'message': 'Invalid Driver onboarding code'},
                }),
                400,
              );
            }
            verified = true;
            return ok({'verified': true});
          }
          if (r.url.path == '/provider/enrolment') {
            if (r.method == 'PATCH') {
              final b = jsonDecode(r.body) as Map;
              if (b['deferSetup'] == true) {
                deferred = true;
                progress['vehicle_assignment'] = 'skipped';
                writes.add('defer');
              } else if (b['complete'] == true) {
                completed = true;
                writes.add('complete');
              } else {
                progress[b['step'] as String] = b['skipped'] == true
                    ? 'skipped'
                    : 'completed';
                writes.add(b['step'] as String);
              }
            }
            return ok(state());
          }
          // Completed Driver refresh reads the established operational contracts.
          if (r.url.path == '/rides/driver/assigned-vehicle') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'NO_ASSIGNED_VEHICLE'},
              }),
              404,
            );
          }
          if (r.url.path == '/provider/onboarding') {
            return ok({'requirements': []});
          }
          if (r.url.path == '/partners/me') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'PARTNER_NOT_FOUND'},
              }),
              404,
            );
          }
          return ok([]);
        }),
      );
      final s = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );

      expect(await s.authenticateGoogle('fixture', signup: true), true);
      expect(s.landingPath, '/role-selection');
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/role-selection',
        routes: [
          GoRoute(
            path: '/role-selection',
            builder: (_, _) => const RoleSelectionScreen(),
          ),
          GoRoute(
            path: '/role-onboarding',
            builder: (_, _) => const RoleOnboardingScreen(),
          ),
          GoRoute(
            path: '/fleet/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Real Fleet route')),
          ),
          GoRoute(
            path: '/driver/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Real Driver route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: s,
          child: MaterialApp.router(theme: Ops.theme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('How will you use INFURNUS?'), findsOneWidget);
      final roleTitle = ProviderRoleCards.options
          .firstWhere((o) => o.$1 == role)
          .$2;
      await tester.tap(find.text(roleTitle));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(s.landingPath, '/role-onboarding');
      expect(api.providerMode, role == 'driver' ? 'driver' : 'fleet_owner');
      expect(writes.where((w) => w == 'role'), hasLength(1));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('../docs/role-flow-$role-390.png'),
      );
      if (role == 'driver') {
        expect(find.text('Skip for now'), findsOneWidget);
        expect(find.text('Your driving licence'), findsNothing);
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();
        expect(find.text('Real Driver route'), findsOneWidget);
        expect(s.roleEnrolment!['assignmentStatus'], 'unassigned');
        expect(s.assignedVehicle, isNull);
        expect(writes, ['role', 'defer']);
        await s.refresh();
        expect(s.dashboardAllowed, true);
        expect(s.roleEnrolment!['assignmentStatus'], 'unassigned');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
        return;
      }
      if (role == 'driver_fleet_owner') {
        await tester.tap(find.text('Add licence details'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Licence details are optional'),
          findsOneWidget,
        );
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();
        expect(s.roleEnrolment!['progress']['licence'], 'skipped');
      }
      for (final step in steps.where(
        (x) => x != 'code' && !(role == 'driver_fleet_owner' && x == 'licence'),
      )) {
        expect(s.roleEnrolment!['progress'].containsKey(step), false);
        await tester.ensureVisible(find.text('Skip for now'));
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();
        expect(s.roleEnrolment!['progress'][step], 'skipped');
      }
      await tester.tap(find.text('Open dashboard'));
      await tester.pumpAndSettle();
      expect(
        find.text(role == 'driver' ? 'Real Driver route' : 'Real Fleet route'),
        findsOneWidget,
      );
      expect(writes.where((x) => x == 'complete').length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
}

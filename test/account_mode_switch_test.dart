import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/core/theme.dart';
import 'package:infurnus_driver/providers/app_state.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:provider/provider.dart';

class _ProviderApi extends ApiService {
  _ProviderApi(http.Client client, MemorySessionStore store)
    : super(client: client, store: store);

  @override
  bool get roleFlowEnabled => true;
}

class _VerifiedSession extends DriverSession {
  _VerifiedSession(ApiService api) : super(api: api);

  @override
  bool get authenticated => api.accessToken != null;
}

void main() {
  setUpAll(() {
    InfurnusTheme.isTesting = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> openProfile(WidgetTester tester, DriverSession session) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider<DriverSession>.value(value: session),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/profile');
    await tester.pumpAndSettle();
  }

  for (final role in ['driver', 'fleet_owner', 'driver_fleet_owner']) {
    testWidgets('Profile mode access and switching for $role', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemorySessionStore();
      final requests = <String>[];
      final enrolment = {'role': role, 'dashboardAccessible': true};
      final client = MockClient((request) async {
        final path = request.url.path;
        requests.add(path);
        if (path == '/rides/driver/profile' || path == '/partners/me') {
          final code = path == '/partners/me'
              ? 'PARTNER_NOT_FOUND'
              : 'DRIVER_PROFILE_NOT_FOUND';
          return http.Response(
            jsonEncode({
              'error': {'code': code},
            }),
            404,
          );
        }
        final Object data = switch (path) {
          '/provider/enrolment' => enrolment,
          '/auth/refresh' => {'accessToken': 'fixture-session'},
          '/provider/approvals' ||
          '/provider/document-requirements' ||
          '/provider/fleet-drivers' ||
          '/provider/logistics-dispatch' => [],
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      });
      final api = _ProviderApi(client, store)
        ..role = role
        ..providerMode = role == 'fleet_owner' ? 'fleet_owner' : 'driver'
        ..userId = 'fixture-account'
        ..accessToken = 'fixture-session';
      final session = _VerifiedSession(api)
        ..restoring = false
        ..roleEnrolment = enrolment;
      addTearDown(session.dispose);
      await openProfile(tester, session);

      expect(find.text('Profile & Settings'), findsOneWidget);
      if (role != 'driver_fleet_owner') {
        expect(find.text('Account Mode'), findsNothing);
        return;
      }

      expect(find.text('Current mode · Driver Mode'), findsOneWidget);
      await tester.tap(find.text('Account Mode'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fleet Owner Mode'));
      await tester.tap(find.text('Fleet Owner Mode'));
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/fleet/dashboard',
      );
      expect(find.text('Fleet Overview'), findsOneWidget);
      expect(api.accessToken, 'fixture-session');
      expect(api.userId, 'fixture-account');
      expect(requests.where((path) => path.startsWith('/auth/')), isEmpty);

      final reopened = _ProviderApi(client, store);
      expect(await reopened.restoreSession(), isTrue);
      expect(reopened.providerMode, 'fleet_owner');
      expect(reopened.role, 'driver_fleet_owner');

      appRouter.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Current mode · Fleet Owner Mode'), findsOneWidget);
      await tester.tap(find.text('Account Mode'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Driver Mode'));
      await tester.tap(find.text('Driver Mode'));
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/driver/dashboard',
      );
      expect(find.text('Today’s Ride Summary'), findsOneWidget);
      expect(api.accessToken, 'fixture-session');
      expect(await store.readMode('fixture-account'), 'driver');
      expect(tester.takeException(), isNull);
    });
  }
}

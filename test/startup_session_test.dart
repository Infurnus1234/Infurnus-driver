import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

String saved() => jsonEncode({
  'accessToken': 'fixture-expired',
  'userId': 'fixture',
  'role': 'driver',
  'cookies': {
    'infurnus_refresh_token': 'fixture-refresh',
    'infurnus_csrf_token': 'fixture-csrf',
  },
  'csrfToken': 'fixture-csrf',
});
http.Response success(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

class StartupProductionApi extends ApiService {
  StartupProductionApi(http.Client client, SessionStore store)
    : super(client: client, store: store);
  @override
  bool get roleFlowEnabled => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'temporary refresh outage recovers to the authorized role dashboard',
    () async {
      final store = MemorySessionStore();
      await store.write(
        jsonEncode({
          'accessToken': 'fixture-expired',
          'userId': 'fixture',
          'role': 'fleet_owner',
          'providerMode': 'fleet_owner',
          'cookies': <String, String>{},
        }),
      );
      var refreshes = 0;
      final api = StartupProductionApi(
        MockClient((request) async {
          switch (request.url.path) {
            case '/auth/refresh':
              if (++refreshes == 1) return http.Response('{}', 503);
              return success({'accessToken': 'fixture-fresh'});
            case '/provider/enrolment':
              return success({
                'role': 'fleet_owner',
                'dashboardAccessible': true,
              });
            case '/users/fixture':
              return success({'id': 'fixture', 'firstName': 'Fixture'});
            default:
              return success({});
          }
        }),
        store,
      );
      final session = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );
      expect(await session.restore(), true);
      expect(refreshes, 2);
      expect(session.authenticated, true);
      expect(session.restorationNeedsRetry, false);
      expect(session.landingPath, '/fleet/dashboard');
      session.dispose();
    },
  );

  test('no saved session completes normally and lands at sign-in', () async {
    final api = ApiService(
      client: MockClient((_) async => throw StateError('No network expected')),
    );
    final session = DriverSession(
      api: api,
      onboardingDraftStore: MemorySessionStore(),
    );
    expect(await session.restore(), true);
    expect(session.authenticated, false);
    expect(session.restorationNeedsRetry, false);
    expect(session.landingPath, '/login');
    session.dispose();
  });

  test('all refresh callers share one rotating-cookie request', () async {
    var count = 0;
    final response = Completer<http.Response>();
    final api = ApiService(
      client: MockClient((_) {
        count++;
        return response.future;
      }),
    );
    final first = api.refreshSession();
    final second = api.refreshSession();
    response.complete(success({'accessToken': 'fresh-fixture'}));
    await Future.wait([first, second]);
    expect(count, 1);
    expect(api.accessToken, 'fresh-fixture');
    api.dispose();
  });

  for (final status in [401, 403]) {
    test(
      'invalid refresh $status clears saved credentials and reaches sign-in',
      () async {
        final store = MemorySessionStore();
        await store.write(saved());
        var calls = 0;
        final api = ApiService(
          store: store,
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': 'Invalid session'},
              }),
              status,
            );
          }),
        );
        final session = DriverSession(
          api: api,
          onboardingDraftStore: MemorySessionStore(),
        );
        expect(await session.restore(), false);
        expect(session.authenticated, false);
        expect(session.restorationNeedsRetry, false);
        expect(session.landingPath, '/login');
        await Future<void>.delayed(Duration.zero);
        expect(await store.read(), isNull);
        expect(calls, 1);
        session.dispose();
      },
    );
  }

  test('temporary server outage is bounded, preserves credentials, and allows recovery', () async {
    final store = MemorySessionStore();
    await store.write(saved());
    var calls = 0;
    final api = ApiService(
      store: store,
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {'message': 'Unavailable'},
          }),
          503,
        );
      }),
    );
    final session = DriverSession(
      api: api,
      onboardingDraftStore: MemorySessionStore(),
    );
    final first = session.restore();
    final second = session.restore();
    expect(identical(first, second), true);
    expect(await first, false);
    expect(calls, 2);
    expect(await store.read(), isNotNull);
    expect(session.restorationNeedsRetry, true);
    expect(session.restoring, false);
    expect(session.authenticated, false);
    expect(session.landingPath, '/login');
    session.dispose();
  });

  test(
    'network disconnect preserves saved session after bounded retry',
    () async {
      final store = MemorySessionStore();
      await store.write(saved());
      var calls = 0;
      final api = ApiService(
        store: store,
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      final session = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );
      expect(await session.restore(), false);
      expect(calls, 2);
      expect(await store.read(), isNotNull);
      expect(session.restorationNeedsRetry, true);
      session.dispose();
    },
  );

  test(
    'refresh uses saved CSRF/cookie and persists rotated access token',
    () async {
      final store = MemorySessionStore();
      await store.write(saved());
      final api = ApiService(
        store: store,
        client: MockClient((request) async {
          expect(request.url.path, '/auth/refresh');
          expect(request.headers['X-CSRF-Token'], 'fixture-csrf');
          expect(
            request.headers['Cookie'],
            contains('infurnus_refresh_token=fixture-refresh'),
          );
          return success({
            'accessToken': 'fresh-fixture',
            'csrfToken': 'rotated-csrf',
          });
        }),
      );
      expect(await api.restoreSession(), true);
      expect(api.accessToken, 'fresh-fixture');
      expect(jsonDecode((await store.read())!)['accessToken'], 'fresh-fixture');
      api.dispose();
    },
  );
}

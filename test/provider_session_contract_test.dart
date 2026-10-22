import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/providers/driver_session.dart';

class ProductionFlowApi extends ApiService {
  ProductionFlowApi(http.Client client, SessionStore store)
    : super(client: client, store: store);
  @override
  bool get roleFlowEnabled => true;
}

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  for (final role in ['driver', 'fleet_owner', 'driver_fleet_owner']) {
    test('$role is explicit when retrying an ambiguous OTP identity', () async {
      final api = ApiService(
        client: MockClient((r) async {
          expect(jsonDecode(r.body)['role'], role);
          return ok({'challengeId': 'fixture-challenge'});
        }),
      );
      expect(
        await api.login('fixture@example.invalid', '', role),
        'fixture-challenge',
      );
      api.dispose();
    });
    test('$role Google selection is sent as account intent', () async {
      final token =
          'x.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.x';
      final api = ApiService(
        client: MockClient((r) async {
          if (r.url.path == '/auth/google') {
            expect(jsonDecode(r.body)['accountRole'], role);
            return ok({'accessToken': token, 'userId': 'fixture'});
          }
          if (r.url.path == '/provider/enrolment') return ok({'role': role});
          return http.Response(
            jsonEncode({
              'error': {'code': 'DRIVER_PROFILE_NOT_FOUND'},
            }),
            404,
          );
        }),
      );
      await api.authenticateGoogle(
        'fixture-google',
        signup: true,
        accountRole: role,
      );
      expect(api.role, role);
      api.dispose();
    });
  }
  test('Driver OTP login does not require a Fleet password', () async {
    final api = ApiService(
      client: MockClient((r) async {
        expect(r.url.path, '/auth/login');
        expect(jsonDecode(r.body), {'phone': '+918000000001'});
        return ok({'challengeId': 'fixture-challenge'});
      }),
    );
    final session = DriverSession(api: api);
    expect(await session.login('8000000001', ''), true);
    expect(session.challengeId, 'fixture-challenge');
    session.dispose();
  });
  for (final role in ['fleet_owner', 'driver_fleet_owner']) {
    for (final blocked in [false, true]) {
      test('$role restore uses authoritative enrolment; blocked=$blocked', () async {
        final store = MemorySessionStore();
        final token =
            'x.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.x';
        await store.write(
          jsonEncode({
            'accessToken': token,
            'userId': 'fixture',
            'role': role,
            'providerMode': 'fleet_owner',
            'cookies': <String, String>{},
          }),
        );
        final api = ProductionFlowApi(
          MockClient((r) async {
            if (r.url.path == '/auth/refresh') {
              return ok({'accessToken': token});
            }
            if (r.url.path == '/provider/enrolment') {
              if (blocked) {
                return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'FORBIDDEN',
                      'message': 'Active provider account required',
                    },
                  }),
                  403,
                );
              }
              return ok({
                'role': role,
                'completed': true,
                'dashboardAccessible': true,
              });
            }
            if (r.url.path == '/users/fixture') {
              // Exact production profile projection: no role or status fields.
              return ok({
                'id': 'fixture',
                'firstName': 'Fixture',
                'lastName': 'Owner',
              });
            }
            if (r.url.path == '/notifications/devices') {
              return ok({'id': 'device'});
            }
            fail('Unexpected request ${r.url.path}');
          }),
          store,
        );
        final session = DriverSession(api: api);
        expect(await session.restore(), !blocked);
        expect(session.restorationNeedsRetry, blocked);
        expect(session.dashboardAllowed, false);
        if (!blocked) expect(session.landingPath, '/fleet/dashboard');
        session.dispose();
      });
    }
  }
  test('a mismatching provider role is rejected', () async {
    final api = ApiService(
      client: MockClient((_) async => ok({'role': 'customer'})),
    );
    api.role = 'fleet_owner';
    await expectLater(
      api.validateProviderAccount(),
      throwsA(isA<ApiException>()),
    );
    api.dispose();
  });
}

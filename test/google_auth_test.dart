import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
http.Response failure(int status, String code) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': code},
  }),
  status,
);

void main() {
  for (final providerRole in ['driver', 'fleet_owner', 'driver_fleet_owner']) {
    test(
      'Google signup authenticates selected $providerRole without onboarding payload',
      () async {
        final token =
            'header.${base64Url.encode(utf8.encode(jsonEncode({'role': providerRole}))).replaceAll('=', '')}.signature';
        final api = ApiService(
          client: MockClient((r) async {
            if (r.url.path == '/auth/google') {
              expect(jsonDecode(r.body), {
                'idToken': 'google-fixture',
                'driverFlow': 'signup',
                'providerRole': providerRole,
              });
              return ok({'accessToken': token, 'userId': 'provider-fixture'});
            }
            if (r.url.path == '/users/provider-fixture') {
              return ok({'role': providerRole, 'status': 'active'});
            }
            expect(r.url.path, '/rides/driver/profile');
            return failure(404, 'DRIVER_PROFILE_NOT_FOUND');
          }),
        );
        await api.authenticateGoogle(
          'google-fixture',
          signup: true,
          providerRole: providerRole,
        );
        expect(api.role, providerRole);
        expect(
          api.providerMode,
          providerRole == 'fleet_owner' ? 'fleet_owner' : 'driver',
        );
        api.dispose();
      },
    );
  }
  test('combined provider mode survives logout and subsequent Google signin', () async {
    final store = MemorySessionStore();
    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver_fleet_owner'}))).replaceAll('=', '')}.signature';
    ApiService createApi() => ApiService(
      store: store,
      client: MockClient((r) async {
        if (r.url.path == '/auth/google') {
          return ok({'accessToken': token, 'userId': 'combined-fixture'});
        }
        if (r.url.path == '/users/combined-fixture') {
          return ok({'role': 'driver_fleet_owner', 'status': 'active'});
        }
        return failure(404, 'DRIVER_PROFILE_NOT_FOUND');
      }),
    );
    final first = createApi();
    await first.authenticateGoogle('google-fixture');
    await first.setProviderMode('fleet_owner');
    await first.logout();
    expect(store.value, isNull);
    first.dispose();
    final second = createApi();
    await second.authenticateGoogle('google-fixture');
    expect(second.providerMode, 'fleet_owner');
    second.dispose();
  });

  for (final signup in [false, true]) {
    test(
      'Google ${signup ? 'signup' : 'signin'} sends only identity and intent, then validates the protected Driver profile',
      () async {
        final paths = <String>[];
        final api = ApiService(
          client: MockClient((r) async {
            paths.add(r.url.path);
            if (r.url.path == '/auth/google') {
              expect(jsonDecode(r.body), {
                'idToken': 'fixture-google-token',
                'driverFlow': signup ? 'signup' : 'signin',
              });
              return ok({
                'accessToken': 'fixture-driver-token',
                'userId': 'fixture-user',
              });
            }
            expect(r.url.path, '/rides/driver/profile');
            expect(r.headers['Authorization'], 'Bearer fixture-driver-token');
            return failure(404, 'DRIVER_PROFILE_NOT_FOUND');
          }),
        );
        expect(
          await api.authenticateGoogle('fixture-google-token', signup: signup),
          isEmpty,
        );
        expect(api.accessToken, 'fixture-driver-token');
        expect(paths, ['/auth/google', '/rides/driver/profile']);
        api.dispose();
      },
    );
  }
  test('new Google Driver lands in onboarding with required licence/KYC and no operational access', () async {
    final paths = <String>[];
    final api = ApiService(
      client: MockClient((r) async {
        paths.add(r.url.path);
        switch (r.url.path) {
          case '/auth/google':
            return ok({
              'accessToken': 'fixture-token',
              'userId': 'fixture-user',
            });
          case '/rides/driver/profile':
            return failure(404, 'DRIVER_PROFILE_NOT_FOUND');
          case '/partners/me':
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {
                  'code': 'PARTNER_NOT_FOUND',
                  'message': 'No owned partner',
                },
              }),
              404,
            );
          case '/users/fixture-user':
            return ok({'firstName': 'Fixture', 'lastName': 'Driver'});
          case '/provider/document-requirements':
            return ok([
              {
                'document_code': 'driver_license',
                'required': true,
                'requires_expiry': true,
                'minimum_pages': 1,
              },
            ]);
          case '/provider/approvals':
            return ok([]);
          default:
            fail('Unexpected request ${r.url.path}');
        }
      }),
    );
    final session = DriverSession(api: api);
    session.challengeId = 'previous-password-challenge';
    expect(
      await session.authenticateGoogle('fixture-google-token', signup: true),
      isTrue,
    );
    expect(session.authenticated, isTrue);
    expect(session.challengeId, isNull);
    expect(session.signupId, isNull);
    expect(
      paths.where(
        (path) =>
            path.contains('verify') ||
            path == '/auth/signup' ||
            path == '/auth/login',
      ),
      isEmpty,
    );
    expect(session.dashboardAllowed, isFalse);
    expect(session.landingPath, '/onboarding');
    expect(
      session.documentRules.map((r) => r.code),
      contains('driver_license'),
    );
    expect(await session.setOnline(true), isFalse);
    expect(paths, isNot(contains('/rides/driver/availability')));
    session.dispose();
  });
  test(
    'Google cannot retain a session when the protected API denies Driver role',
    () async {
      final api = ApiService(
        client: MockClient(
          (r) async => r.url.path == '/auth/google'
              ? ok({'accessToken': 'fixture-customer-token'})
              : failure(403, 'FORBIDDEN'),
        ),
      );
      await expectLater(
        api.authenticateGoogle('fixture-token'),
        throwsA(isA<ApiException>()),
      );
      expect(api.accessToken, isNull);
      api.dispose();
    },
  );
  test('Google backend account conflict is not retried as signup', () async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((r) async {
        calls++;
        expect(jsonDecode(r.body)['driverFlow'], 'signin');
        return failure(409, 'GOOGLE_ACCOUNT_LINK_CONFLICT');
      }),
    );
    await expectLater(
      api.authenticateGoogle('fixture-token'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
    expect(api.accessToken, isNull);
    api.dispose();
  });
  test('authenticated Google linking sends bearer/CSRF, accepts the existing response and keeps Driver eligibility unchanged', () async {
    var invalid = false;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.url.path == '/auth/google') {
          return ok({
            'accessToken': 'fixture-token',
            'csrfToken': 'fixture-csrf',
          });
        }
        if (r.url.path == '/rides/driver/profile') {
          return ok({'id': 'fixture-profile', 'verificationStatus': 'pending'});
        }
        expect(r.url.path, '/auth/google/link');
        expect(r.headers['Authorization'], 'Bearer fixture-token');
        expect(r.headers['X-CSRF-Token'], 'fixture-csrf');
        expect(jsonDecode(r.body), {'idToken': 'fixture-link-token'});
        return invalid
            ? failure(401, 'INVALID_GOOGLE_TOKEN')
            : http.Response('{"success":true}', 200);
      }),
    );
    expect(
      (await api.authenticateGoogle('fixture-token'))['verificationStatus'],
      'pending',
    );
    await api.linkGoogle('fixture-link-token');
    expect(api.accessToken, 'fixture-token');
    invalid = true;
    await expectLater(
      api.linkGoogle('fixture-link-token'),
      throwsA(isA<ApiException>()),
    );
    expect(api.accessToken, 'fixture-token');
    api.dispose();
  });
  test('missing Google names are completed through the protected account API without OTP', () async {
    final paths = <String>[];
    var firstName = '';
    var lastName = '';
    final api = ApiService(
      client: MockClient((r) async {
        paths.add('${r.method} ${r.url.path}');
        switch (r.url.path) {
          case '/auth/google':
            return ok({
              'accessToken': 'fixture-token',
              'userId': 'fixture-user',
            });
          case '/rides/driver/profile':
            return failure(404, 'DRIVER_PROFILE_NOT_FOUND');
          case '/partners/me':
            return failure(404, 'PARTNER_NOT_FOUND');
          case '/provider/document-requirements':
            return ok([
              {
                'document_code': 'driver_license',
                'required': true,
                'requires_expiry': true,
                'minimum_pages': 1,
              },
            ]);
          case '/provider/approvals':
            return ok([]);
          case '/users/fixture-user':
            if (r.method == 'PATCH') {
              expect(r.headers['Authorization'], 'Bearer fixture-token');
              expect(jsonDecode(r.body), {
                'firstName': 'Fixture',
                'lastName': 'Driver',
              });
              firstName = 'Fixture';
              lastName = 'Driver';
            }
            return ok({'firstName': firstName, 'lastName': lastName});
          default:
            fail('Unexpected request ${r.url.path}');
        }
      }),
    );
    final session = DriverSession(api: api);
    expect(
      await session.authenticateGoogle('fixture-google-token', signup: true),
      isTrue,
    );
    expect(session.authenticated, isTrue);
    expect(session.landingPath, '/onboarding');
    expect(await session.saveAccountNames(' Fixture ', ' Driver '), isTrue);
    expect(session.account?['firstName'], 'Fixture');
    expect(session.dashboardAllowed, isFalse);
    expect(
      paths.where(
        (p) =>
            p.contains('verify') ||
            p.contains('/auth/signup') ||
            p.contains('/auth/login'),
      ),
      isEmpty,
    );
    expect(paths, contains('PATCH /users/fixture-user'));
    session.dispose();
  });
}

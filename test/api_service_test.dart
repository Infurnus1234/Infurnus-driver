import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';

http.Response success(dynamic data, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: headers ?? const {},
    );

void main() {
  test(
    'driver applications preserve backend pagination outside data',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/driver-applications');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {'id': 'application-fixture'},
              ],
              'pagination': {'page': 2, 'limit': 100, 'total': 101},
            }),
            200,
          );
        }),
      );
      final result = await api.request(
        'GET',
        '/driver-applications?page=2&limit=100',
      );
      expect(result, {
        'items': [
          {'id': 'application-fixture'},
        ],
        'total': 101,
      });
      api.dispose();
    },
  );

  test('password login requests production challenge and never authenticates early', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.url.origin, ApiService.baseUrl);
        expect(request.url.path, '/auth/login');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'phone': '+919876543210',
          'password': 'test-password',
        });
        return success({'challengeId': 'challenge-fixture'});
      }),
    );
    expect(
      await api.login('+91 98765 43210', 'test-password'),
      'challenge-fixture',
    );
    expect(api.accessToken, isNull);
    api.dispose();
  });

  test('connection failure cannot become simulated login success', () async {
    final api = ApiService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      api.login('driver@example.invalid', 'test-password'),
      throwsA(isA<ApiException>()),
    );
    expect(api.accessToken, isNull);
    api.dispose();
  });

  test(
    'OTP token is accepted only after protected driver profile succeeds',
    () async {
      final paths = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/auth/login/verify') {
            expect(jsonDecode(request.body), {
              'challengeId': 'challenge-fixture',
              'otp': '654321',
            });
            return success({'accessToken': 'test-access-token'});
          }
          expect(request.headers['Authorization'], 'Bearer test-access-token');
          expect(request.url.path, '/rides/driver/profile');
          return success({
            'id': 'driver-fixture',
            'verificationStatus': 'approved',
          });
        }),
      );
      expect(
        (await api.verifyLogin('challenge-fixture', '654321'))['id'],
        'driver-fixture',
      );
      expect(paths, ['/auth/login/verify', '/rides/driver/profile']);
      api.dispose();
    },
  );

  test(
    'customer/unauthorized profile cannot leave a driver session authenticated',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login/verify') {
            return success({'accessToken': 'customer-test-token'});
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'message': 'Driver role required'},
            }),
            403,
          );
        }),
      );
      await expectLater(
        api.verifyLogin('challenge-fixture', '654321'),
        throwsA(isA<ApiException>()),
      );
      expect(api.accessToken, isNull);
      api.dispose();
    },
  );

  test('invalid OTP is rejected without making a network request', () async {
    final api = ApiService(
      client: MockClient((_) async {
        fail('Request must not be sent');
      }),
    );
    await expectLater(
      api.verifyLogin('challenge-fixture', '1234'),
      throwsA(isA<ApiException>()),
    );
    api.dispose();
  });

  test('non JSON server errors remain failures', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('<html>Unavailable</html>', 503),
      ),
    );
    await expectLater(
      api.login('driver@example.invalid', 'test-password'),
      throwsA(isA<ApiException>()),
    );
    api.dispose();
  });

  test(
    'expired access refreshes with cookies and CSRF before retrying once',
    () async {
      var profileRequests = 0;
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/auth/login/verify') {
            return success(
              {'accessToken': 'expired-test-token', 'csrfToken': 'test-csrf'},
              headers: {
                'set-cookie': 'infurnus_refresh_token=test-refresh; HttpOnly; Secure, infurnus_csrf_token=test-csrf; Secure',
              },
            );
          }
          if (request.url.path == '/auth/refresh') {
            expect(
              request.headers['Cookie'],
              contains('infurnus_refresh_token=test-refresh'),
            );
            expect(request.headers['X-CSRF-Token'], 'test-csrf');
            return success({'accessToken': 'fresh-test-token'});
          }
          profileRequests++;
          if (profileRequests == 1) {
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'message': 'Expired'},
              }),
              401,
            );
          }
          expect(request.headers['Authorization'], 'Bearer fresh-test-token');
          return success({'id': 'driver-fixture'});
        }),
      );
      await api.verifyLogin('challenge-fixture', '654321');
      expect(profileRequests, 2);
      expect(api.accessToken, 'fresh-test-token');
      api.dispose();
    },
  );
}

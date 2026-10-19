import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  test('temporary session prefixes requests, stays memory-only and never refreshes normal auth', () async {
    final paths = <String>[];
    final store = MemorySessionStore();
    final api = ApiService(
      store: store,
      client: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path == '/driver-test-onboarding/sessions') {
          return ok({'sessionToken': 'restricted-token', 'userId': 'own-user'});
        }
        if (r.url.path.endsWith('/profile')) return ok({'userId': 'own-user'});
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'INVALID_TEST_ONBOARDING_SESSION',
              'message': 'Expired',
            },
          }),
          401,
        );
      }),
    );
    await api.startTestOnboarding();
    expect(api.isTestOnboarding, isTrue);
    expect(await store.read(), isNull);
    await api.request(
      'POST',
      '/rides/driver/profile',
      body: {'licenseNumber': 'LOCAL-TEST'},
    );
    await expectLater(
      api.request('GET', '/users/own-user'),
      throwsA(isA<ApiException>()),
    );
    expect(paths, [
      '/driver-test-onboarding/sessions',
      '/driver-test-onboarding/rides/driver/profile',
      '/driver-test-onboarding/users/own-user',
    ]);
    expect(api.accessToken, isNull);
    expect(api.isTestOnboarding, isFalse);
    api.dispose();
  });

  test('disabled backend invalidates the temporary frontend session', () async {
    final api = ApiService(
      client: MockClient(
        (r) async => r.url.path.endsWith('/sessions')
            ? ok({'sessionToken': 'restricted-token', 'userId': 'own-user'})
            : http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'code': 'NOT_FOUND', 'message': 'Not found'},
                }),
                404,
              ),
      ),
    );
    await api.startTestOnboarding();
    await expectLater(
      api.request('GET', '/users/own-user'),
      throwsA(isA<ApiException>()),
    );
    expect(api.isTestOnboarding, isFalse);
    expect(api.accessToken, isNull);
    api.dispose();
  });
}

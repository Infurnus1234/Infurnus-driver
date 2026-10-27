import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

class RealHttp extends HttpOverrides {}

class ContractHttp extends http.BaseClient {
  final delegate = IOClient(RealHttp().createHttpClient(null));
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    // No bodies, query strings, identities, cookies or authorization headers.
    // ignore: avoid_print
    print(
      'HTTP ${request.method} ${request.url.path.replaceAll(RegExp(r'[a-f0-9]{8}-[a-f0-9-]{27,}'), '<id>')} ${response.statusCode} ${response.headers['content-type']}',
    );
    return response;
  }

  @override
  void close() => delegate.close();
}

void main() {
  const enabled = bool.fromEnvironment('FULL_STACK_BACKEND_CONTRACT');
  const prefix = String.fromEnvironment('FULL_STACK_FIXTURE_PREFIX');
  test('real Driver client authenticates, resumes onboarding and paginates persisted support over HTTP', () async {
    expect(ApiService.baseUrl, 'http://127.0.0.1:3110');
    expect(prefix, startsWith('full-stack-'));
    for (final role in ['driver', 'fleet_owner', 'driver_fleet_owner']) {
      final store = MemorySessionStore();
      ApiService open() => ApiService(store: store, client: ContractHttp());
      var api = open();
      final signup = await api.signup({
        'firstName': 'TEST_SAMPLE',
        'lastName': 'Contract',
        'email': '$prefix-$role@example.invalid',
        'role': role,
        if (role != 'fleet_owner') 'onboardingLicencePending': true,
        if (role != 'driver') ...{
          'businessName': 'TEST_SAMPLE Contract',
          'password': 'Contract-only-pass-2026',
          'confirmPassword': 'Contract-only-pass-2026',
        },
      });
      await api.verifySignup(
        signup,
        '123456',
      ); // Local DevOtpProvider; no delivery.
      expect(api.role, role);
      final userId = api.userId;
      final state = await api.request('GET', '/provider/enrolment');
      expect(state['role'], role);
      expect(state['dashboardAccessible'], false);
      await api.request(
        'PATCH',
        '/users/$userId',
        body: {'firstName': 'Saved', 'lastName': 'Contract'},
      );
      for (final step in state['steps'] as List) {
        await api.request(
          'PATCH',
          '/provider/enrolment',
          body: {'step': step, 'skipped': true},
        );
      }
      api.dispose();
      api = open();
      expect(await api.restoreSession(), true);
      expect(api.userId, userId);
      expect(api.role, role);
      final restored = await api.request('GET', '/provider/enrolment');
      expect((restored['progress'] as Map).values, everyElement('skipped'));
      expect(
        (await api.request('GET', '/users/$userId'))['firstName'],
        'Saved',
      );
      await api.request(
        'PATCH',
        '/provider/enrolment',
        body: {'complete': true},
      );
      expect(
        (await api.request(
          'GET',
          '/provider/enrolment',
        ))['dashboardAccessible'],
        true,
      );
      if (role == 'driver') {
        for (var i = 0; i < 26; i++) {
          final ticket = await api.request(
            'POST',
            '/support/tickets',
            body: {
              'category': 'App',
              'subject': 'Contract ticket $i',
              'message': 'TEST_SAMPLE persisted description',
            },
          );
          expect(ticket['status'], 'OPEN');
          expect(ticket['userId'], userId);
        }
        final first = await api.request(
          'GET',
          '/support/tickets?includePagination=true&page=1&pageSize=25',
        );
        final last = await api.request(
          'GET',
          '/support/tickets?includePagination=true&page=2&pageSize=25',
        );
        expect(first['pagination']['hasNext'], true);
        expect(last['pagination']['hasNext'], false);
        expect(first['items'], hasLength(25));
        expect(last['items'], hasLength(1));
        expect({
          ...((first['items'] as List).map((x) => x['id'])),
          ...((last['items'] as List).map((x) => x['id'])),
        }, hasLength(26));
      }
      await api.logout();
      expect(store.value, isNull);
      final challenge = await api.login(
        '$prefix-$role@example.invalid',
        role == 'driver' ? '' : 'Contract-only-pass-2026',
        role,
      );
      await api.verifyLogin(challenge, '123456');
      expect(api.userId, userId);
      expect(api.role, role);
      expect(
        (await api.request('GET', '/users/$userId'))['firstName'],
        'Saved',
      );
      await api.logout();
      expect(store.value, isNull);
      api.dispose();
    }
  }, skip: !enabled);
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';

void main() {
  test('delayed support 401 uses the already rotated token instead of invalidating the session', () async {
    var refreshes = 0, oldRequests = 0;
    final retried = Completer<void>();
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshes++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'accessToken': 'fresh-support-token'},
            }),
            refreshes == 1 ? 200 : 401,
          );
        }
        if (request.headers['Authorization'] == 'Bearer fresh-support-token') {
          if (!retried.isCompleted) retried.complete();
          return http.Response('{"success":true,"data":[]}', 200);
        }
        oldRequests++;
        if (oldRequests == 2) await retried.future;
        return http.Response(
          '{"success":false,"error":{"code":"INVALID_ACCESS_TOKEN","message":"Expired"}}',
          401,
        );
      }),
    )..accessToken = 'expired-support-token';
    addTearDown(api.dispose);
    final responses = await Future.wait([
      api.request('GET', '/support/tickets'),
      api.request('GET', '/support/tickets'),
    ]);
    expect(responses, [[], []]);
    expect(refreshes, 1);
    expect(api.accessToken, 'fresh-support-token');
  });
}

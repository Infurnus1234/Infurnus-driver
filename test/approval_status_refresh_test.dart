import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

void main() {
  test('refresh retrieves server approval changes and preserves previous data on failure', () async {
    var status = 'PENDING';
    var failRefresh = false;
    http.Response ok(dynamic data) =>
        http.Response(jsonEncode({'success': true, 'data': data}), 200);
    final session = DriverSession(
      api: ApiService(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (failRefresh && r.url.path == '/provider/approvals') {
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {
                  'code': 'UNAVAILABLE',
                  'message': 'Retry status refresh',
                },
              }),
              503,
            );
          }
          switch (r.url.path) {
            case '/auth/google':
              return ok({
                'accessToken': 'fixture-access',
                'userId': 'fixture-user',
              });
            case '/users/fixture-user':
              return ok({
                'id': 'fixture-user',
                'role': 'driver',
                'status': 'active',
              });
            case '/rides/driver/profile':
              return ok({
                'id': 'fixture-profile',
                'userId': 'fixture-user',
                'verificationStatus': status,
              });
            case '/rides/driver/assigned-vehicle':
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'NO_ASSIGNED_VEHICLE',
                    'message': 'No vehicle',
                  },
                }),
                404,
              );
            case '/provider/document-requirements':
            case '/rides/driver/documents':
              return ok([]);
            case '/provider/approvals':
              return ok([
                {'id': 'fixture-request', 'status': status},
              ]);
            case '/driver-applications':
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [],
                  'pagination': {'total': 0},
                }),
                200,
              );
            case '/partners/me':
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'code': 'PARTNER_NOT_FOUND', 'message': 'No fleet'},
                }),
                404,
              );
            default:
              fail('Unexpected request path');
          }
        }),
      ),
    );
    try {
      expect(await session.authenticateGoogle('fixture-google'), true);
      expect(session.approvals.single['status'], 'PENDING');
      status = 'REJECTED';
      expect(await session.refresh(), true);
      expect(session.approvals.single['status'], 'REJECTED');
      expect(session.profile!['verificationStatus'], 'REJECTED');
      failRefresh = true;
      expect(await session.refresh(), false);
      expect(session.error, contains('Retry status refresh'));
      expect(session.approvals.single['status'], 'REJECTED');
    } finally {
      session.dispose();
    }
  });
}

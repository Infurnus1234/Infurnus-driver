import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/support_request_id.dart';

class RealSupportHttp extends HttpOverrides {}

void main() {
  const enabled = bool.fromEnvironment('SUPPORT_LIVE_CONTRACT');
  test(
    'driver app client creates a persistent ticket; actual Admin Panel proxy resolves and closes it',
    () async {
      const backend = 'http://127.0.0.1:3142',
          adminBase = 'http://127.0.0.1:3143';
      final client = IOClient(RealSupportHttp().createHttpClient(null));
      addTearDown(client.close);
      final fixtures = jsonDecode(
        (await client.get(Uri.parse('$backend/__support_fixture'))).body,
      ) as Map;
      final owner = fixtures['driver'] as Map;
      final adminCookie =
          'infurnus_admin_access=${fixtures['super_admin']['token']}';
      ApiService open() => ApiService(client: client)
        ..accessToken = owner['token'] as String
        ..userId = owner['id'] as String;
      final api = open();
      expect(ApiService.baseUrl, backend);
      Future<Map> create(Map<String, dynamic> body) async =>
          await api.request('POST', '/support/tickets', body: body) as Map;
      Future<Map> get(String reference) async =>
          await open().request('GET', '/support/tickets/$reference') as Map;
      Future<List<Map>> list() async =>
          (await api.request('GET', '/support/tickets') as List).cast<Map>();

      Future<Map> admin(
        String path, {
        String method = 'GET',
        Map? body,
        int status = 200,
      }) async {
        final request = http.Request(
          method,
          Uri.parse('$adminBase/api/backend$path'),
        );
        request.headers.addAll({
          'Cookie': adminCookie,
          'Origin': adminBase,
          'Content-Type': 'application/json',
        });
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        expect(response.statusCode, status);
        return jsonDecode(response.body) as Map;
      }

      final body = {
        'category': 'App',
        'subject': 'TEST_SAMPLE driver cannot book',
        'message': 'TEST_SAMPLE live support lifecycle through the app client.',
        'requestId': supportRequestId(),
      };
      final before = await list();
      await expectLater(
        create({...body, 'message': 'tiny'}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 400)
              .having((error) => error.code, 'code', 'VALIDATION_ERROR')
              .having(
                (error) => error.message,
                'message',
                'Message must be at least 5 characters.',
              ),
        ),
      );
      expect((await list()).length, before.length);
      final paged = await api.request(
        'GET',
        '/support/tickets?page=1&pageSize=25&includePagination=true',
      );
      expect(paged['items'], isA<List>());
      expect(paged['pagination']['page'], 1);
      await expectLater(
        get('INF-SUP-9999999999999999999'),
        throwsA(
          isA<ApiException>().having((error) => error.status, 'status', 404),
        ),
      );
      final created = await create(body);
      expect(
        created['ticketNumber'],
        matches(RegExp(r'^INF-SUP-[0-9]{6,19}$')),
      );
      expect(created['status'], 'OPEN');
      expect((await create(body))['id'], created['id']);
      final number = created['ticketNumber'] as String,
          id = created['id'] as String;
      expect((await get(number))['id'], id);
      final page = await client.get(
        Uri.parse('$adminBase/super-admin/support'),
        headers: {'Cookie': adminCookie},
      );
      expect(page.statusCode, 200);
      final visible = await admin('/admin/operations/support?search=$number');
      final record = (visible['data']['items'] as List).singleWhere(
        (row) => row['id'] == id,
      ) as Map;
      expect(record['message'], body['message']);
      expect(record['role'], 'driver');
      expect(record['status'], 'OPEN');
      var version = record['version'] as int;
      for (final status in ['UNDER_REVIEW', 'RESOLVED', 'CLOSED']) {
        final result = await admin(
          '/admin/operations/support/$id/status',
          method: 'PATCH',
          body: {'status': status, 'expectedVersion': version},
        );
        version = result['data']['version'] as int;
        expect((await get(number))['status'], status);
        expect(
          (await list()).singleWhere((row) => row['id'] == id)['status'],
          status,
        );
      }
      final persisted = await admin('/admin/operations/support?recordId=$id');
      expect(persisted['data']['items'][0]['status'], 'CLOSED');
      await admin(
        '/admin/operations/support/$id/status',
        method: 'PATCH',
        body: {'status': 'OPEN', 'expectedVersion': version},
        status: 409,
      );
      final denied = await client.get(
        Uri.parse('$backend/support/tickets/$number'),
        headers: {'Authorization': 'Bearer ${fixtures['other']['token']}'},
      );
      expect(denied.statusCode, 403);
      final login =
          await api.request('GET', '/__support_session/driver') as Map;
      final expired = login['accessToken'] as String;
      api.accessToken = expired;
      final reads = await Future.wait([
        api.request('GET', '/support/tickets'),
        api.request('GET', '/support/tickets'),
      ]);
      expect(
        reads.every(
          (tickets) => (tickets as List).any(
            (ticket) => ticket['id'] == id && ticket['status'] == 'CLOSED',
          ),
        ),
        isTrue,
      );
      expect(api.accessToken, isNot(expired));
      final stats = jsonDecode(
        (await client.get(
          Uri.parse('$backend/__support_session_status/driver'),
        )).body,
      ) as Map;
      expect(stats['records'], 2);
      expect(stats['active'], 1);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

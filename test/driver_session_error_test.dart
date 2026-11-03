import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';

void main() {
  test('DriverSession.run handles server-written 503, non-JSON 502, JSON 500 without message, 4xx and status=null', () async {
    // 1. Server-written 503 message passes through
    final api503 = ApiService(
      client: MockClient(
        (r) async =>
            http.Response('{"error":{"message":"Temporary outage"}}', 503),
      ),
    );
    final session503 = DriverSession(api: api503);
    await session503.run(() async {
      await api503.request('GET', '/test');
    });
    expect(session503.error, "Temporary outage");
    session503.dispose();

    // 2. Non-JSON 502 body -> generic message
    final api502 = ApiService(
      client: MockClient(
        (r) async => http.Response('<html>502 Bad Gateway</html>', 502),
      ),
    );
    final session502 = DriverSession(api: api502);
    await session502.run(() async {
      await api502.request('GET', '/test');
    });
    expect(
      session502.error,
      "We couldn't load this information. Please try again.",
    );
    session502.dispose();

    // 3. JSON 500 with no message -> generic message
    final api500NoMsg = ApiService(
      client: MockClient((r) async => http.Response('{"error":{}}', 500)),
    );
    final session500NoMsg = DriverSession(api: api500NoMsg);
    await session500NoMsg.run(() async {
      await api500NoMsg.request('GET', '/test');
    });
    expect(
      session500NoMsg.error,
      "We couldn't load this information. Please try again.",
    );
    session500NoMsg.dispose();

    // 4. 4xx error passes through
    final api400 = ApiService(
      client: MockClient(
        (r) async => http.Response(
          '{"error":{"message":"Invalid request parameters"}}',
          400,
        ),
      ),
    );
    final session400 = DriverSession(api: api400);
    await session400.run(() async {
      await api400.request('GET', '/test');
    });
    expect(session400.error, "Invalid request parameters");
    session400.dispose();

    // 5. status = null ApiException passes through
    final sessionNullStatus = DriverSession(
      api: ApiService(
        client: MockClient((r) async => http.Response('{}', 200)),
      ),
    );
    await sessionNullStatus.run(() async {
      throw const ApiException(
        'Custom local validation message',
        null,
        'CUSTOM_CODE',
      );
    });
    expect(sessionNullStatus.error, "Custom local validation message");
    sessionNullStatus.dispose();
  });
}

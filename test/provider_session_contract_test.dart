import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

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

class DisabledGps extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async {
    return false;
  }
}

Position sample(DateTime at) => Position(
  latitude: 25.6183341,
  longitude: 85.1218192,
  timestamp: at,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class WorkingGps extends GeolocatorPlatform {
  final at = DateTime.now().toUtc();
  final updates = StreamController<Position>.broadcast();
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => sample(at);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return updates.stream;
  }
}

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  testWidgets(
    'GPS unavailable does not fail an authenticated active-trip session restore',
    (tester) async {
      final previous = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = DisabledGps();
      addTearDown(() => GeolocatorPlatform.instance = previous);
      final store = MemorySessionStore();
      final token =
          'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver'})))}.x';
      await store.write(
        jsonEncode({
          'accessToken': token,
          'userId': 'fixture',
          'role': 'driver',
          'providerMode': 'driver',
          'cookies': <String, String>{},
        }),
      );
      final api = ProductionFlowApi(
        MockClient((r) async {
          switch (r.url.path) {
            case '/auth/refresh':
              return ok({'accessToken': token});
            case '/provider/enrolment':
              return ok({'role': 'driver', 'dashboardAccessible': false});
            case '/users/fixture':
              return ok({'firstName': 'Fixture', 'lastName': 'Driver'});
            case '/rides/driver/profile':
              return ok({'id': 'fixture-profile'});
            case '/rides/driver/current-trip':
              return ok({'id': 'fixture-trip', 'status': 'driver_arriving'});
            case '/rides/driver/assigned-vehicle':
              return ok({'id': 'fixture-vehicle'});
            default:
              return ok({});
          }
        }),
        store,
      );
      final session = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );
      // A real stored session is revalidated before the GPS capability is attempted.
      expect(await session.restore(), true);
      expect(session.authenticated, true);
      expect(session.restorationNeedsRetry, false);
      expect(session.landingPath, '/driver/active-trip');
      expect(session.error, contains('Enable GPS'));
      session.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'stationary location stays fresh and duplicate/older GPS samples are not resent',
    (tester) async {
      final previous = GeolocatorPlatform.instance;
      final gps = WorkingGps();
      GeolocatorPlatform.instance = gps;
      final sent = <String>[];
      addTearDown(() => GeolocatorPlatform.instance = previous);
      final store = MemorySessionStore();
      final token =
          'x.${base64Url.encode(utf8.encode(jsonEncode({'role': 'driver'})))}.x';
      await store.write(
        jsonEncode({
          'accessToken': token,
          'userId': 'fixture',
          'role': 'driver',
          'providerMode': 'driver',
          'cookies': <String, String>{},
        }),
      );
      final api = ProductionFlowApi(
        MockClient((r) async {
          switch (r.url.path) {
            case '/rides/driver/location':
              sent.add(jsonDecode(r.body)['timestamp'] as String);
              return ok(null);
            case '/auth/refresh':
              return ok({'accessToken': token});
            case '/provider/enrolment':
              return ok({'role': 'driver', 'dashboardAccessible': false});
            case '/users/fixture':
              return ok({'firstName': 'Fixture', 'lastName': 'Driver'});
            case '/rides/driver/profile':
              return ok({'id': 'fixture-profile'});
            case '/rides/driver/current-trip':
              return ok({'id': 'fixture-trip', 'status': 'driver_arriving'});
            case '/rides/driver/assigned-vehicle':
              return ok({'id': 'fixture-vehicle'});
            default:
              return ok({});
          }
        }),
        store,
      );
      final session = DriverSession(
        api: api,
        onboardingDraftStore: MemorySessionStore(),
      );
      // A real stored session is revalidated before the GPS capability is attempted.
      expect(await session.restore(), true);
      expect(session.authenticated, true);
      expect(session.restorationNeedsRetry, false);
      expect(session.landingPath, '/driver/active-trip');
      expect(sent.length, 1);
      expect(gps.settings!.distanceFilter, 0);
      gps.updates.add(sample(gps.at));
      gps.updates.add(sample(gps.at.subtract(const Duration(seconds: 1))));
      await tester.pump(const Duration(milliseconds: 10));
      expect(sent.length, 1);
      gps.updates.add(sample(gps.at.add(const Duration(seconds: 5))));
      await tester.pump(const Duration(milliseconds: 10));
      expect(sent.length, 2);
      expect(
        DateTime.parse(sent.last).isAfter(DateTime.parse(sent.first)),
        true,
      );
      await gps.updates.close();
      session.dispose();
      await tester.pump(const Duration(seconds: 1));
    },
  );
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
        expect(await session.restore(), true);
        expect(session.restorationNeedsRetry, false);
        expect(session.dashboardAllowed, false);
        expect(
          session.landingPath,
          blocked ? '/role-onboarding' : '/fleet/dashboard',
        );
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

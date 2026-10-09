import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/models/provider_status.dart';
import 'package:infurnus_driver/providers/provider_assets.dart';
import 'package:infurnus_driver/providers/driver_session.dart';

http.Response ok(dynamic data, {Map<String, String>? headers}) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: headers ?? const {},
);
String token(String role) =>
    'fixture.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';
void main() {
  test('unsupported signup role is rejected before any request', () async {
    final api = ApiService(
      client: MockClient((_) async {
        fail('Unsupported role must not reach backend');
      }),
    );
    await expectLater(
      api.signup({'role': 'admin'}),
      throwsA(isA<ApiException>()),
    );
    api.dispose();
  });
  for (final role in ['driver', 'fleet_owner', 'driver_fleet_owner']) {
    test(
      '$role signup sends only backend registration requirements, with no local approval',
      () async {
        final api = ApiService(
          client: MockClient((r) async {
            final data = jsonDecode(r.body) as Map;
            expect(data['role'], role);
            expect(data.containsKey('verificationStatus'), false);
            expect(data.containsKey('status'), false);
            expect(data.containsKey('businessName'), role != 'driver');
            expect(data.containsKey('licenseNumber'), role != 'fleet_owner');
            return ok({'signupId': 'fixture-signup'});
          }),
        );
        final data = {
          'role': role,
          'firstName': 'Fixture',
          'lastName': 'Account',
          'email': 'fixture@example.invalid',
          'password': 'fixture-password',
          'confirmPassword': 'fixture-password',
          if (role != 'driver') 'businessName': 'Fixture Fleet',
          if (role != 'fleet_owner') 'licenseNumber': 'Fixture',
          if (role != 'fleet_owner') 'licenseExpiry': '2099-12-31',
          'verificationStatus': 'approved',
          'status': 'active',
        };
        expect(OnboardingRules.validateSignup(data), null);
        expect(await api.signup(data), 'fixture-signup');
        expect(api.accessToken, null);
        api.dispose();
      },
    );
  }
  test(
    'Fleet account validates its backend role without calling Driver APIs',
    () async {
      final paths = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path == '/auth/login/verify') {
            return ok({'accessToken': token('fleet_owner'), 'userId': 'fleet'});
          }
          expect(r.url.path, '/users/fleet');
          return ok({'id': 'fleet', 'role': 'fleet_owner', 'status': 'active'});
        }),
      );
      expect(await api.verifyLogin('challenge', '123456'), isEmpty);
      expect(api.hasFleetRole, true);
      expect(api.hasDriverRole, false);
      expect(api.providerMode, 'fleet_owner');
      expect(paths, ['/auth/login/verify', '/users/fleet']);
      api.dispose();
    },
  );
  test('customer token cannot create a provider session or reach provider resources', () async {
    final api = ApiService(
      client: MockClient((r) async {
        expect(r.url.path, '/auth/google');
        return ok({'accessToken': token('customer'), 'userId': 'customer'});
      }),
    );
    await expectLater(
      api.authenticateGoogle('fixture-id-token'),
      throwsA(isA<ApiException>()),
    );
    expect(api.accessToken, null);
    api.dispose();
  });
  test('secure session restoration refreshes cookie/CSRF and resumes server onboarding; dispose preserves storage and logout clears it', () async {
    final store = MemorySessionStore();
    http.Client client() => MockClient((r) async {
      switch (r.url.path) {
        case '/auth/google':
          return ok(
            {
              'accessToken': 'fixture-access',
              'userId': 'fixture-user',
              'csrfToken': 'fixture-csrf',
            },
            headers: {
              'set-cookie': 'infurnus_refresh_token=fixture-refresh; HttpOnly, infurnus_csrf_token=fixture-csrf; Path=/',
            },
          );
        case '/auth/refresh':
          expect(r.headers['Cookie'], contains('fixture-refresh'));
          expect(r.headers['X-CSRF-Token'], 'fixture-csrf');
          return ok({'accessToken': 'rotated-access'});
        case '/rides/driver/profile':
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'DRIVER_PROFILE_NOT_FOUND',
                'message': 'Profile missing',
              },
            }),
            404,
          );
        case '/provider/document-requirements':
        case '/provider/approvals':
          return ok([]);
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
          return ok({
            'id': 'fixture-user',
            'role': 'driver',
            'status': 'active',
          });
        case '/auth/logout':
          return ok({});
        default:
          fail('Unexpected request ${r.url.path}');
      }
    });
    final first = DriverSession(
      api: ApiService(client: client(), store: store),
    );
    expect(await first.authenticateGoogle('fixture-google'), true);
    first.dispose();
    expect(await store.read(), isNotNull);
    final restored = DriverSession(
      api: ApiService(client: client(), store: store),
    );
    expect(await restored.restore(), true);
    expect(restored.authenticated, true);
    expect(restored.landingPath, '/onboarding');
    expect(restored.dashboardAllowed, false);
    expect(restored.api.accessToken, 'rotated-access');
    await restored.logout();
    expect(await store.read(), null);
    restored.dispose();
  });
  test('status normalization separates submission, approval, rejection, expiry and unknown', () {
    expect(providerStatus('approved'), ProviderStatus.approved);
    expect(providerStatus('VERIFIED'), ProviderStatus.approved);
    expect(providerStatus('SUBMITTED'), ProviderStatus.submitted);
    expect(providerStatus('REJECTED'), ProviderStatus.rejected);
    expect(providerStatus('EXPIRED'), ProviderStatus.expired);
    expect(providerStatus('ACTIVE'), ProviderStatus.unknown);
  });
  test('vehicle binary pages remain associated with partner/vehicle, and rejected documents use replacement', () async {
    final paths = <String>[];
    bool replaced = false;
    final api = ApiService(
      client: MockClient((r) async {
        paths.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/replace/pages')) {
          expect(r.body, contains('name="files"'));
          expect(r.body, contains('filename="front.pdf"'));
          expect(r.body, contains('filename="back.pdf"'));
          expect(r.body, contains('%PDF-'));
          expect(r.body, contains('documentCode'));
          expect(r.body, isNot(contains('name="status"')));
          replaced = true;
          return ok({'id': 'document'});
        }
        if (r.method == 'PATCH') {
          expect(jsonDecode(r.body), {'status': 'SUBMITTED'});
          return ok({'id': 'document'});
        }
        if (r.url.path == '/provider/approval-requests') {
          expect(jsonDecode(r.body), {
            'targetType': 'partner_document',
            'targetId': 'document',
            'requestType': 'document_reverification',
          });
          return ok({'id': 'request', 'status': 'PENDING'});
        }
        switch (r.url.path) {
          case '/partners/me':
            return ok({'id': 'partner', 'approvalStatus': 'approved'});
          case '/partners/partner/documents':
            return ok([
              {
                'id': 'document',
                'vehicleId': 'vehicle',
                'documentType': 'OTHER',
                'metadata': {'documentCode': 'custom_vehicle_doc'},
                'status': replaced ? 'SUBMITTED' : 'REJECTED',
              },
            ]);
          case '/partners/vehicles':
          case '/provider/approvals':
          case '/provider/document-requirements':
            return ok([]);
          case '/provider/earnings':
            return ok({'periods': []});
          default:
            fail('Unexpected ${r.url.path}');
        }
      }),
    );
    final assets = ProviderAssets(api);
    await assets.refresh();
    final files = [
      DocumentFile(
        'front.pdf',
        Uint8List.fromList(utf8.encode('%PDF-fixture front')),
        'application/pdf',
      ),
      DocumentFile(
        'back.pdf',
        Uint8List.fromList(utf8.encode('%PDF-fixture back')),
        'application/pdf',
      ),
    ];
    expect(
      await assets.uploadDocument(
        const DocumentRule('custom_vehicle_doc', minimumPages: 2),
        files,
        {'uploadSource': 'FILE'},
        vehicleId: 'vehicle',
      ),
      true,
    );
    expect(
      paths,
      contains('POST /partners/partner/documents/document/replace/pages'),
    );
    expect(paths.any((p) => p.contains('/rides/driver/documents')), false);
    expect(assets.documents.single['status'], 'SUBMITTED');
    assets.dispose();
    api.dispose();
  });
}

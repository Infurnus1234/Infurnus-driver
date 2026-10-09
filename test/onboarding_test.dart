import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
http.Response missing(String code) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': code},
  }),
  404,
);
Map<String, dynamic> signup() => {
  'firstName': 'Test',
  'lastName': 'Fixture',
  'email': 'driver@example.invalid',
  'password': 'fixture-password',
  'confirmPassword': 'fixture-password',
  'licenseNumber': 'fixture-license',
  'licenseExpiry': '2099-12-31',
};

void main() {
  test(
    'signup uses a challenge, driver role and whitelisted fields only',
    () async {
      final api = ApiService(
        client: MockClient((r) async {
          expect(r.url.path, '/auth/signup');
          final body = jsonDecode(r.body) as Map;
          expect(body['role'], 'driver');
          expect(body.containsKey('verificationStatus'), isFalse);
          expect(body.containsKey('status'), isFalse);
          return ok({'signupId': 'fixture-signup'});
        }),
      );
      expect(
        await api.signup({
          ...signup(),
          'role': 'driver',
          'status': 'active',
          'verificationStatus': 'approved',
        }),
        'fixture-signup',
      );
      expect(api.accessToken, isNull);
      api.dispose();
    },
  );
  test(
    'signup OTP and resend use signup endpoints and protected profile',
    () async {
      final api = ApiService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/resend')) {
            expect(jsonDecode(r.body), {'signupId': 'old'});
            return ok({'signupId': 'new'});
          }
          if (r.url.path == '/auth/signup/verify') {
            expect(jsonDecode(r.body), {'signupId': 'new', 'otp': '123456'});
            return ok({'accessToken': 'fixture-token'});
          }
          expect(r.url.path, '/rides/driver/profile');
          return missing('DRIVER_PROFILE_NOT_FOUND');
        }),
      );
      expect(await api.resendSignup('old'), 'new');
      expect(await api.verifySignup('new', '123456'), isEmpty);
      expect(api.accessToken, 'fixture-token');
      api.dispose();
    },
  );
  test('unknown profile 404 fails authentication closed', () async {
    final api = ApiService(
      client: MockClient(
        (r) async => r.url.path.startsWith('/auth/')
            ? ok({'accessToken': 'fixture-token'})
            : missing('UNRELATED_NOT_FOUND'),
      ),
    );
    await expectLater(
      api.verifySignup('signup', '123456'),
      throwsA(isA<ApiException>()),
    );
    expect(api.accessToken, isNull);
    api.dispose();
  });
  test(
    'profile fields and dates follow backend mandatory and optional rules',
    () {
      expect(OnboardingRules.validateSignup(signup()), isNull);
      expect(
        OnboardingRules.validateSignup({...signup(), 'phone': '123'}),
        isNotNull,
      );
      expect(
        OnboardingRules.validateSignup({
          ...signup(),
          'confirmPassword': 'different',
        }),
        isNotNull,
      );
      expect(
        OnboardingRules.validateSignup({...signup(), 'email': ''}),
        isNotNull,
      );
      expect(
        OnboardingRules.validateProfile({
          'licenseNumber': 'fixture',
          'licenseExpiry': '2099-12-31',
        }),
        isNull,
      );
      expect(
        OnboardingRules.validateProfile({
          'licenseNumber': 'fixture',
          'licenseExpiry': '2000-01-01',
        }),
        isNotNull,
      );
      expect(OnboardingRules.validDate('2026-02-30'), isFalse);
      expect(
        OnboardingRules.validateProfile({
          'licenseNumber': 'fixture',
          'licenseExpiry': '2099-12-31',
          'dob': '2099-01-01',
        }),
        isNotNull,
      );
    },
  );
  test(
    'required expiry, page count and accepted upload types are enforced',
    () {
      final pdf = DocumentFile(
        'fixture.pdf',
        Uint8List.fromList([37, 80, 68, 70]),
        'application/pdf',
      );
      const rule = DocumentRule(
        'driver_license',
        required: true,
        requiresExpiry: true,
        minimumPages: 2,
      );
      expect(
        OnboardingRules.validateFiles(rule, [pdf], {'expiresAt': '2099-12-31'}),
        isNotNull,
      );
      expect(OnboardingRules.validateFiles(rule, [pdf, pdf], {}), isNotNull);
      expect(
        OnboardingRules.validateFiles(
          rule,
          [pdf, pdf],
          {'expiresAt': '2099-12-31'},
        ),
        isNull,
      );
      expect(
        OnboardingRules.validateFiles(const DocumentRule('profile_photo'), [
          pdf,
        ], {}),
        isNotNull,
      );
      expect(
        OnboardingRules.validateFiles(
          const DocumentRule('identity'),
          [pdf],
          {'issuedAt': '2099-12-31', 'expiresAt': '2099-01-01'},
        ),
        isNotNull,
      );
      expect(const DocumentRule('vehicle_insurance').uploadType, 'other');
      expect(const DocumentRule('vehicle_rc').uploadType, 'vehicle_rc');
    },
  );
  test(
    'multipart upload sends real bytes and custom policy metadata',
    () async {
      final api = ApiService(
        client: MockClient((r) async {
          expect(r.url.path, '/rides/driver/documents/other/pages');
          expect(
            r.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          expect(r.body, contains('name="files"; filename="front.pdf"'));
          expect(r.body, contains('name="documentCode"'));
          expect(r.body, contains('vehicle_insurance'));
          expect(r.body, contains('application/pdf'));
          return ok({'id': 'doc', 'verificationStatus': 'pending'});
        }),
      );
      final pdf = DocumentFile(
        'front.pdf',
        Uint8List.fromList([37, 80, 68, 70]),
        'application/pdf',
      );
      await api.uploadDriverDocument(
        'other',
        [pdf, pdf],
        {'documentCode': 'vehicle_insurance', 'uploadSource': 'FILE'},
      );
      api.dispose();
    },
  );
  test('incomplete, rejected and pending states cannot go online or access dashboard', () async {
    final paths = <String>[];
    Map<String, dynamic>? profile;
    var docs = <Map<String, dynamic>>[];
    var applications = <Map<String, dynamic>>[];
    var hasVehicle = false;
    final api = ApiService(
      client: MockClient((r) async {
        paths.add(r.url.path);
        switch (r.url.path) {
          case '/auth/login':
            return ok({'challengeId': 'challenge'});
          case '/auth/login/verify':
            return ok({'accessToken': 'fixture-token'});
          case '/rides/driver/profile':
            return profile == null
                ? missing('DRIVER_PROFILE_NOT_FOUND')
                : ok(profile);
          case '/rides/driver/assigned-vehicle':
            return hasVehicle
                ? ok({
                    'id': 'vehicle',
                    'category': 'sedan',
                    'plateNumber': 'fixture',
                  })
                : missing('NO_ASSIGNED_VEHICLE');
          case '/provider/document-requirements':
            return ok([
              {
                'document_code': 'identity',
                'required': true,
                'requires_expiry': false,
                'minimum_pages': 1,
              },
            ]);
          case '/provider/approvals':
            return ok([]);
          case '/rides/driver/documents':
            return ok(docs);
          case '/driver-applications':
            return http.Response(
              jsonEncode({
                'success': true,
                'data': applications,
                'pagination': {
                  'page': 1,
                  'limit': 100,
                  'total': applications.length,
                },
              }),
              200,
            );
          default:
            fail('Blocked driver must not call ${r.url.path}');
        }
      }),
    );
    final s = DriverSession(api: api);
    expect(await s.login('driver@example.invalid', 'fixture-password'), isTrue);
    expect(await s.verify('123456'), isTrue);
    expect(s.authenticated, isTrue);
    expect(s.landingPath, '/onboarding');
    expect(s.dashboardAllowed, isFalse);
    profile = {
      'id': 'profile',
      'licenseNumber': 'fixture',
      'licenseExpiry': '2099-12-31',
      'verificationStatus': 'pending',
    };
    docs = [
      {
        'id': 'document',
        'documentType': 'identity',
        'verificationStatus': 'pending',
        'documentMetadata': {},
      },
    ];
    expect(await s.refresh(), isTrue);
    expect(s.landingPath, '/verification-status');
    expect(s.dashboardAllowed, isFalse);
    profile['verificationStatus'] = 'rejected';
    expect(await s.refresh(), isTrue);
    expect(s.dashboardAllowed, isFalse);
    profile['verificationStatus'] = 'approved';
    hasVehicle = true;
    docs.first['verificationStatus'] = 'approved';
    applications = [
      {'driverProfileId': 'profile', 'status': 'CHANGES_REQUESTED'},
    ];
    expect(await s.refresh(), isTrue);
    expect(s.dashboardAllowed, isFalse);
    expect(await s.setOnline(true), isFalse);
    expect(paths, isNot(contains('/rides/driver/availability')));
    s.applications = [];
    expect(s.dashboardAllowed, isTrue);
    s.documents.first['verificationStatus'] = 'rejected';
    expect(s.dashboardAllowed, isFalse);
    s.dispose();
  });
}

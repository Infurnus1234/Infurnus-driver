import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/providers/provider_assets.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';

import 'guided_onboarding_test.dart' show image;

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
http.Response unavailable() => http.Response(
  jsonEncode({
    'error': {'code': 'UNAVAILABLE', 'message': 'Fixture unavailable'},
  }),
  503,
);
void main() {
  test('acknowledged driver photo stays saved when refresh fails; recovery reads do not re-upload', () async {
    var uploads = 0;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.method == 'POST' && r.url.path.contains('/documents/')) {
          uploads++;
          return ok({
            'id': 'photo',
            'documentType': 'profile_photo',
            'verificationStatus': 'pending',
          });
        }
        return unavailable();
      }),
    );
    final s = DriverSession(
      api: api,
      onboardingDraftStore: MemorySessionStore(),
    );
    addTearDown(s.dispose);
    s.profile = {
      'id': 'profile',
      'licenseNumber': 'fixture',
      'licenseExpiry': '2099-12-31',
    };
    s.onboardingLoaded = true;
    expect(
      await s.uploadDocument(const DocumentRule('profile_photo'), [image], {}),
      isTrue,
    );
    expect(uploads, 1);
    expect(s.requirementDocument('profile_photo')?['id'], 'photo');
    expect(s.refreshWarning, contains('Saved on the server'));
    expect(s.busy, isFalse);
    expect(await s.refresh(), isFalse);
    expect(uploads, 1);
    expect(s.onboardingLoaded, isTrue);
  });
  test(
    'acknowledged vehicle creation is retained during a failed status refresh',
    () async {
      var writes = 0;
      final api = ApiService(
        client: MockClient((r) async {
          if (r.method == 'POST' && r.url.path == '/partners/vehicles') {
            writes++;
            return ok({
              'id': 'owned-vehicle',
              'registrationNumber': 'FIXTURE',
              'approvalStatus': 'PENDING',
            });
          }
          return unavailable();
        }),
      );
      addTearDown(api.dispose);
      final assets = ProviderAssets(api);
      addTearDown(assets.dispose);
      assets.partner = {'id': 'partner'};
      assets.loaded = true;
      expect(
        await assets.saveVehicle({'registrationNumber': 'FIXTURE'}),
        isTrue,
      );
      expect(assets.vehicles.single['id'], 'owned-vehicle');
      expect(assets.vehicles.single['approvalStatus'], 'PENDING');
      expect(assets.loaded, isTrue);
      expect(assets.refreshWarning, isNotNull);
      expect(await assets.refresh(), isFalse);
      expect(writes, 1);
    },
  );
  test('fleet upload retry resumes status submission without uploading the same file twice', () async {
    var uploads = 0, submits = 0, reviews = 0;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/upload')) {
          uploads++;
          return ok({
            'id': 'doc',
            'documentType': 'OTHER',
            'status': 'DRAFT',
            'metadata': {'documentCode': 'vehicle_front_photo'},
          });
        }
        if (r.method == 'PATCH') {
          submits++;
          return submits == 1 ? unavailable() : ok({});
        }
        if (r.url.path == '/provider/approval-requests') {
          reviews++;
          return ok({'id': 'review'});
        }
        return unavailable();
      }),
    );
    addTearDown(api.dispose);
    final assets = ProviderAssets(api);
    addTearDown(assets.dispose);
    assets.partner = {'id': 'partner'};
    const rule = DocumentRule('vehicle_front_photo', required: true);
    expect(
      await assets.uploadDocument(rule, [image], {}, vehicleId: 'vehicle'),
      isFalse,
    );
    expect(
      await assets.uploadDocument(rule, [image], {}, vehicleId: 'vehicle'),
      isTrue,
    );
    expect(uploads, 1);
    expect(submits, 2);
    expect(reviews, 1);
    expect(assets.busy, isFalse);
    expect(assets.refreshWarning, isNotNull);
  });
  test('acknowledged vehicle assignment survives status-refresh failure without another claim', () async {
    var claims = 0;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.url.path == '/rides/driver/assignment/claim-code') {
          claims++;
          return ok({
            'vehicleId': 'vehicle-ack',
            'make': 'Fixture',
            'model': 'Sedan',
            'plateNumber': 'TEST_ONLY',
          });
        }
        return unavailable();
      }),
    );
    final s = DriverSession(
      api: api,
      onboardingDraftStore: MemorySessionStore(),
    );
    addTearDown(s.dispose);
    expect(await s.claimAssignment('001234'), true);
    expect(s.assignedVehicle?['id'], 'vehicle-ack');
    expect(s.refreshWarning, contains('Saved on the server'));
    expect(await s.refresh(), false);
    expect(claims, 1);
  });
}

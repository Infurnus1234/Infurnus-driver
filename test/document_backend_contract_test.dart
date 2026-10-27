import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

import 'full_stack_backend_contract_test.dart' show ContractHttp, RealHttp;

void main() {
  const enabled = bool.fromEnvironment('FULL_STACK_BACKEND_CONTRACT');
  const prefix = String.fromEnvironment('FULL_STACK_FIXTURE_PREFIX');
  test('actual multipart documents, private binary retrieval, review, fresh sessions and encrypted bank correction', () async {
    expect(ApiService.baseUrl, 'http://127.0.0.1:3110');
    final clients = <ApiService>[];
    ApiService open([SessionStore? store]) {
      final api = ApiService(
        client: ContractHttp(),
        store: store ?? MemorySessionStore(),
      );
      clients.add(api);
      return api;
    }

    final binary = IOClient(RealHttp().createHttpClient(null));
    addTearDown(() {
      for (final api in clients) {
        api.dispose();
      }
      binary.close();
    });
    final pdf = DocumentFile(
      'TEST_SAMPLE.pdf',
      Uint8List.fromList(utf8.encode('%PDF-1.7\n1 0 obj\n<<>>\nendobj\n')),
      'application/pdf',
    );
    final image = DocumentFile(
      'TEST_SAMPLE.png',
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1kAAAAASUVORK5CYII=',
      ),
      'image/png',
    );
    Future<ApiService> signup(
      String suffix, {
      String role = 'fleet_owner',
      SessionStore? store,
    }) async {
      final api = open(store);
      final id = await api.signup({
        'firstName': 'TEST_SAMPLE',
        'lastName': 'Document',
        'email': '$prefix-$suffix@example.invalid',
        'role': role,
        if (role == 'fleet_owner') ...{
          'businessName': 'TEST_SAMPLE Documents',
          'password': 'Contract-only-pass-2026',
          'confirmPassword': 'Contract-only-pass-2026',
        } else ...{
          'licenseNumber': 'TEST_SAMPLE_LICENCE',
          'licenseExpiry': '2030-01-01',
        },
      });
      await api.verifySignup(id, '123456');
      return api;
    }

    final store = MemorySessionStore();
    var owner = await signup('owner', store: store);
    final other = await signup('other');
    final partner = await owner.request('GET', '/partners/me');
    final vehicle = await owner.request(
      'POST',
      '/fleet/vehicles',
      body: {
        'make': 'TEST_SAMPLE',
        'model': 'Document',
        'plateNumber': 'TEST${prefix.substring(prefix.length - 10)}',
        'sector': 'passenger',
        'category': 'sedan',
        'registrationDate': '2025-01-01',
        'registrationExpiry': '2030-01-01',
      },
    );
    expect(vehicle['verificationStatus'], 'pending');
    expect(vehicle['isActive'], false);
    final path = '/partners/${partner['id']}/documents';
    final saved = <String, dynamic>{};
    for (final type in [
      'OTHER',
      'VEHICLE_RC',
      'VEHICLE_INSURANCE',
      'VEHICLE_PERMIT',
      'VEHICLE_FITNESS',
      'VEHICLE_PUC',
    ]) {
      final result = await owner.request(
        'POST',
        '$path/upload',
        files: [type == 'OTHER' ? image : pdf],
        fields: {
          'documentType': type,
          'vehicleId': vehicle['id'],
          'issuedAt': '2025-01-01',
          'expiresAt': '2030-01-01',
          if (type == 'OTHER') 'documentCode': 'vehicle_front_photo',
        },
      );
      saved[type] = result;
      expect(result['vehicleId'], vehicle['id']);
      expect(result['status'], 'PENDING');
      expect(result['expiresAt'].toString(), startsWith('2030-01-01'));
      final access = await owner.request(
        'GET',
        '$path/${result['id']}/access-url',
      );
      final response = await binary.get(Uri.parse(access['url']));
      expect(response.statusCode, 200);
      expect(response.bodyBytes, type == 'OTHER' ? image.bytes : pdf.bytes);
      final unsigned = Uri.parse(access['url']).replace(query: '');
      expect((await binary.get(unsigned)).statusCode, 403);
      await expectLater(
        other.request('GET', '$path/${result['id']}/access-url'),
        throwsA(isA<ApiException>().having((e) => e.status, 'ownership', 403)),
      );
      if (type == 'VEHICLE_RC') {
        for (final operation in <Future<dynamic> Function()>[
          () => other.request(
            'POST',
            '$path/upload',
            files: [pdf],
            fields: {'documentType': 'VEHICLE_RC', 'vehicleId': vehicle['id']},
          ),
          () => other.request(
            'POST',
            '$path/${result['id']}/replace',
            files: [pdf],
          ),
          () => other.request('DELETE', '$path/${result['id']}'),
        ]) {
          await expectLater(
            operation(),
            throwsA(
              isA<ApiException>().having(
                (e) => e.status,
                'cross-owner mutation',
                403,
              ),
            ),
          );
        }
      }
    }
    await expectLater(
      owner.request(
        'POST',
        '$path/upload',
        files: [pdf],
        fields: {'documentType': 'PAN', 'expiresAt': '2026-02-30'},
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'invalid date', 400)),
    );
    await expectLater(
      owner.request(
        'POST',
        '$path/upload',
        files: [pdf],
        fields: {'documentType': 'AADHAAR'},
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'collection authorization',
          'IDENTITY_COLLECTION_DISABLED',
        ),
      ),
    );
    await expectLater(
      owner.request(
        'POST',
        '$path/upload',
        files: [DocumentFile('bad.png', pdf.bytes, 'image/png')],
        fields: {
          'documentType': 'OTHER',
          'vehicleId': vehicle['id'],
          'documentCode': 'vehicle_front_photo',
        },
      ),
      throwsA(
        isA<ApiException>().having((e) => e.status, 'invalid image', 400),
      ),
    );
    final admin = open();
    final auth = await admin.request(
      'POST',
      '/auth/admin/login',
      body: {
        'email': '$prefix-reviewer@example.invalid',
        'password': 'Contract-reviewer-only-2026',
      },
    );
    admin.accessToken = auth['accessToken'];
    admin.userId = auth['userId'];
    admin.role = 'admin';
    Future<void> review(
      ApiService applicant,
      String target, {
      String status = 'APPROVED',
      String? reason,
    }) async {
      final rows =
          await applicant.request('GET', '/provider/approvals') as List;
      final request = rows.firstWhere(
        (r) => r['target_id'] == target && r['status'] == 'PENDING',
      );
      final detail = await admin.request(
        'GET',
        '/provider-approvals/${request['id']}',
      );
      await admin.request(
        'POST',
        '/provider-approvals/${request['id']}/review',
        body: {
          'status': status,
          'expectedUpdatedAt': detail['target']['updated_at'],
          'reason': ?reason,
        },
      );
    }

    for (final document in saved.values) {
      await review(owner, document['id']);
    }
    final rc = saved['VEHICLE_RC'];
    final replacement = await owner.request(
      'POST',
      '$path/${rc['id']}/replace',
      files: [pdf],
      fields: {'issuedAt': '2025-01-01', 'expiresAt': '2031-01-01'},
    );
    expect(replacement['status'], 'PENDING');
    expect(replacement['version'], 2);
    await review(owner, rc['id']);
    await expectLater(
      owner.request('DELETE', '$path/${rc['id']}'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.status,
          'retain reviewed evidence',
          409,
        ),
      ),
    );
    await review(owner, partner['id']);
    await review(owner, vehicle['id']);
    final refreshed = await owner.request('GET', '/fleet/vehicles') as List;
    expect(refreshed.single['verificationStatus'], 'approved');
    expect(refreshed.single['isActive'], false);
    await owner.request(
      'PUT',
      '/fleet/vehicles/${vehicle['id']}',
      body: {'registrationExpiry': '2031-01-01'},
    );
    expect(
      (await owner.request(
        'GET',
        '/fleet/vehicles',
      ) as List).single['registrationExpiry'],
      '2031-01-01',
    );
    final draft = await owner.request(
      'POST',
      '$path/upload',
      files: [pdf],
      fields: {'documentType': 'OTHER', 'documentCode': 'test_sample_optional'},
    );
    await owner.request('DELETE', '$path/${draft['id']}');
    await expectLater(
      owner.request('GET', '$path/${draft['id']}/access-url'),
      throwsA(
        isA<ApiException>().having((e) => e.status, 'removed draft', 404),
      ),
    );
    final bankInput = {
      'accountHolderName': 'TEST_SAMPLE Owner',
      'accountNumber': '123456789012',
      'ifscCode': 'TEST0001234',
      'bankName': 'TEST_SAMPLE Bank',
    };
    await expectLater(
      owner.request(
        'POST',
        '/provider/bank-account',
        body: {...bankInput, 'ifscCode': 'invalid'},
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'invalid IFSC', 400)),
    );
    final bank = await owner.request(
      'POST',
      '/provider/bank-account',
      body: bankInput,
    );
    expect(bank['isVerified'], false);
    expect(bank['accountNumberLast4'], '9012');
    expect(bank.containsKey('accountNumber'), false);
    final queue =
        await admin.request('GET', '/provider-approvals?group=driver') as List;
    expect(queue.any((r) => r['target_id'] == bank['id']), true);
    final bankRequest = queue.firstWhere((r) => r['target_id'] == bank['id']);
    final bankDetail = await admin.request(
      'GET',
      '/provider-approvals/${bankRequest['id']}?group=driver',
    );
    expect(bankDetail['target'].containsKey('account_number_encrypted'), false);
    expect(bankDetail['target']['account_number_last4'], '9012');
    await expectLater(
      admin.request(
        'POST',
        '/provider-approvals/${bankRequest['id']}/review',
        body: {
          'status': 'APPROVED',
          'expectedUpdatedAt': bankDetail['target']['updated_at'],
        },
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'no fabricated bank verification',
          'BANK_VERIFICATION_NOT_CONFIGURED',
        ),
      ),
    );
    await review(
      owner,
      bank['id'],
      status: 'REJECTED',
      reason: 'Correct the account holder name and resubmit.',
    );
    expect(
      (await owner.request('GET', '/provider/bank-account'))['reviewStatus'],
      'REJECTED',
    );
    await owner.request(
      'POST',
      '/provider/bank-account',
      body: {...bankInput, 'accountHolderName': 'TEST_SAMPLE Corrected'},
    );
    final recovered = open(store);
    expect(await recovered.restoreSession(), true);
    owner = recovered;
    final bankRestored = await owner.request('GET', '/provider/bank-account');
    expect(bankRestored['isVerified'], false);
    expect(bankRestored['reviewStatus'], 'PENDING');
    expect((await owner.request('GET', path) as List).length, 6);
    final driverStore = MemorySessionStore();
    var driver = await signup('driver', role: 'driver', store: driverStore);
    final driverDocs = <String, dynamic>{};
    for (final type in ['pan', 'driver_license', 'profile_photo']) {
      driverDocs[type] = await driver.request(
        'POST',
        '/rides/driver/documents/$type',
        files: [type == 'profile_photo' ? image : pdf],
        fields: {
          if (type != 'profile_photo') 'expiresAt': '2030-01-01',
          if (type == 'driver_license') 'documentNumber': 'TEST_SAMPLE_LICENCE',
          if (type == 'driver_license') 'licenceClasses': 'LMV',
        },
      );
    }
    await review(
      driver,
      driverDocs['pan']['id'],
      status: 'REJECTED',
      reason: 'Provide a clearer copy.',
    );
    final pan = await driver.request(
      'POST',
      '/rides/driver/documents/pan',
      files: [pdf],
      fields: {'expiresAt': '2030-01-01'},
    );
    expect(pan['version'], 2);
    await review(driver, pan['id']);
    await review(driver, driverDocs['driver_license']['id']);
    await review(driver, driverDocs['profile_photo']['id']);
    final freshDriver = open(driverStore);
    expect(await freshDriver.restoreSession(), true);
    driver = freshDriver;
    final documents =
        await driver.request('GET', '/rides/driver/documents') as List;
    expect(documents.length, 3);
    expect(
      documents.firstWhere(
        (d) => d['documentType'] == 'driver_license',
      )['documentMetadata']['licenceClasses'],
      'LMV',
    );
    expect(documents.every((d) => d['verificationStatus'] == 'approved'), true);
    for (final document in documents) {
      final access = await driver.request(
        'GET',
        '/rides/driver/documents/${document['id']}/access-url',
      );
      expect(
        (await binary.get(Uri.parse(access['accessUrl']))).statusCode,
        200,
      );
    }
    await expectLater(
      driver.request(
        'PATCH',
        '/rides/driver/availability',
        body: {'status': 'available'},
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => [403, 409].contains(e.status),
          'unapproved/unassigned Driver restriction',
          true,
        ),
      ),
    );
    await owner.logout();
    await other.logout();
    await driver.logout();
    await admin.logout();
  }, skip: !enabled);
}

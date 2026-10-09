import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';

void main() {
  test('profile, fleet application and review requests never submit approval state', () async {
    final bodies = <String, List<Map<String, dynamic>>>{};
    final profile = <String, dynamic>{
      'id': 'fixture-profile',
      'licenseNumber': 'fixture',
      'licenseExpiry': '2099-12-31',
      'verificationStatus': 'rejected',
      'rejectionReason': 'Correct licence details',
    };
    var reviewed = false;
    final api = ApiService(
      client: MockClient((r) async {
        if (r.method == 'POST' &&
            r.headers['content-type']?.contains('application/json') == true &&
            r.body.isNotEmpty) {
          bodies
              .putIfAbsent(r.url.path, () => [])
              .add(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
        }
        dynamic data;
        switch (r.url.path) {
          case '/auth/login':
            data = {'challengeId': 'fixture-challenge'};
          case '/auth/login/verify':
            data = {'accessToken': 'fixture-token'};
          case '/rides/driver/profile':
            data = profile;
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
            data = [
              {
                'document_code': 'identity',
                'required': true,
                'requires_expiry': false,
                'minimum_pages': 1,
              },
            ];
          case '/rides/driver/documents':
            data = [
              {
                'id': 'fixture-document',
                'documentType': 'identity',
                'verificationStatus': 'rejected',
                'rejectionReason': 'Unreadable image',
                'documentMetadata': {},
              },
            ];
          case '/provider/approvals':
            data = reviewed
                ? [
                    {
                      'request_type': 'driver_verification',
                      'target_type': 'driver_profile',
                      'target_id': 'fixture-profile',
                      'status': 'PENDING',
                    },
                  ]
                : [];
          case '/provider/approval-requests':
            reviewed = true;
            data = {'status': 'PENDING'};
          case '/driver-applications':
            data = r.method == 'GET'
                ? []
                : {'id': 'application', 'status': 'PENDING'};
          case '/rides/driver/assignment/verify-code':
            data = {
              'code': 'fixture-code',
              'vehicle': {
                'id': 'fixture-vehicle',
                'category': 'sedan',
                'plateNumber': 'fixture-plate',
              },
              'owner': {'id': 'owner'},
            };
          case '/rides/driver/assignment/claim-code':
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {
                  'code': 'FORBIDDEN',
                  'message': 'Driver approval and membership required',
                },
              }),
              403,
            );
          default:
            fail('Unexpected request ${r.url.path}');
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': data,
            if (r.method == 'GET' && r.url.path == '/driver-applications')
              'pagination': {'page': 1, 'limit': 100, 'total': 0},
          }),
          200,
        );
      }),
    );
    final session = DriverSession(api: api);
    addTearDown(session.dispose);
    expect(
      await session.login('driver@example.invalid', 'fixture-password'),
      isTrue,
    );
    expect(await session.verify('123456'), isTrue);
    expect(
      await session.saveProfile({
        ...profile,
        'verificationStatus': 'approved',
        'status': 'active',
      }),
      isTrue,
    );
    expect(bodies['/rides/driver/profile']!.single, {
      'licenseNumber': 'fixture',
      'licenseExpiry': '2099-12-31',
    });
    expect(await session.submitOnboarding(), isTrue);
    expect(bodies['/provider/approval-requests'], [
      {
        'targetType': 'driver_document',
        'targetId': 'fixture-document',
        'requestType': 'identity_verification',
      },
      {
        'targetType': 'driver_profile',
        'targetId': 'fixture-profile',
        'requestType': 'driver_verification',
      },
    ]);
    expect(session.profile!['verificationStatus'], 'rejected');
    expect(session.approvals.single['status'], 'PENDING');
    expect(session.dashboardAllowed, isFalse);
    expect(await session.previewAssignment('fixture-code'), isTrue);
    expect(
      session.assignmentPreview!['vehicle']['plateNumber'],
      'fixture-plate',
    );
    expect(await session.claimAssignment('fixture-code'), isFalse);
    expect(session.assignedVehicle, isNull);
    expect(
      await session.applyToFleet({
        'partnerId': '550e8400-e29b-41d4-a716-446655440000',
        'requestedSector': 'passenger',
        'requestedVehicleCategory': 'sedan',
        'driverProfileId': 'other-driver',
        'vehicleOwnershipType': 'PARTNER_OWNED',
        'status': 'APPROVED',
      }),
      isTrue,
    );
    expect(bodies['/driver-applications']!.single, {
      'partnerId': '550e8400-e29b-41d4-a716-446655440000',
      'driverProfileId': 'fixture-profile',
      'requestedSector': 'passenger',
      'requestedVehicleCategory': 'sedan',
      'vehicleOwnershipType': 'DRIVER_ONLY',
    });
  });
}

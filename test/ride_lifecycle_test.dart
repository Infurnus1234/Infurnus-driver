import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/assigned_vehicle_card.dart';
import 'package:infurnus_driver/widgets/ride_pin_dialog.dart';

class PinSession extends DriverSession {
  int attempts = 0;
  String? lastPin;
  final gate = Completer<bool>();
  @override
  Future<bool> transition(String status, {String? pin}) async {
    attempts++;
    lastPin = pin;
    if (attempts == 1) {
      error = 'Incorrect PIN. Try again.';
      return false;
    }
    return gate.future;
  }
}

void main() {
  testWidgets(
    'PIN validation, leading zeros, failure retry and duplicate submission',
    (tester) async {
      final session = PinSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RidePinDialog(session: session)),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(session.attempts, 0);
      await tester.enterText(find.byType(TextField), '0007');
      await tester.pump();
      expect(session.attempts, 0);
      await tester.tap(find.text('Verify & start ride'));
      await tester.pumpAndSettle();
      expect(session.lastPin, '0007');
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      await tester.tap(find.text('Verify & start ride'));
      await tester.tap(find.text('Verify & start ride'));
      await tester.pump();
      expect(session.attempts, 2);
      session.gate.complete(false);
      await tester.pumpAndSettle();
    },
  );
  for (final acknowledged in [false, true]) {
    test(
      'only authoritative trip-start response reveals destination; confirmed start survives failed refresh ($acknowledged)',
      () async {
        final paths = <String>[];
        final api = ApiService(
          client: MockClient((r) async {
            paths.add(r.url.path);
            if (r.url.path == '/rides/ride/verify-pin') {
              expect(jsonDecode(r.body), {'pin': '0007'});
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': acknowledged
                      ? {
                          'verified': true,
                          'ride': {
                            'id': 'ride',
                            'status': 'in_progress',
                            'pinVerified': true,
                            'destinationAddress': 'Authorized destination',
                          },
                        }
                      : {'verified': true},
                }),
                200,
              );
            }
            expect(r.url.path, '/rides/driver/profile');
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'TEMPORARY', 'message': 'Offline'},
              }),
              503,
            );
          }),
        )..accessToken = 'fixture';
        final session = DriverSession(api: api)
          ..currentTrip = {'id': 'ride', 'status': 'driver_arrived'};
        expect(
          await session.transition('in_progress', pin: '0007'),
          acknowledged,
        );
        expect(
          session.currentTrip?['destinationAddress'],
          acknowledged ? 'Authorized destination' : null,
        );
        expect(paths.first, '/rides/ride/verify-pin');
        session.dispose();
      },
    );
  }
  test('invalid or premature PIN never calls the API', () async {
    final session = DriverSession(
      api: ApiService(
        client: MockClient((_) async => throw StateError('must not call')),
      ),
    )..currentTrip = {'id': 'ride', 'status': 'driver_assigned'};
    expect(await session.transition('in_progress', pin: '1234'), false);
    session.dispose();
  });
  for (final missing in [false, true]) {
    testWidgets(
      'vehicle card uses actual registration and handles missing vehicle $missing at 320px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssignedVehicleCard(
                  vehicle: missing
                      ? null
                      : {
                          'plateNumber': 'ACTUAL 7654',
                          'make': 'Actual',
                          'model': 'Vehicle',
                          'verificationStatus': 'pending',
                          'isActive': false,
                          'photoUrl':
                              'https://photos.example.invalid/assigned.jpg',
                        },
                  loading: false,
                  retry: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!missing) {
          expect(find.text('ACTUAL 7654'), findsOneWidget);
          final image = tester.widget<Image>(find.byType(Image));
          expect(
            (image.image as NetworkImage).url,
            'https://photos.example.invalid/assigned.jpg',
          );
          expect(image.fit, BoxFit.contain);
        } else {
          expect(find.text('Manage vehicle assignment'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

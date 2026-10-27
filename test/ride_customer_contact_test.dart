import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/ride_customer_contact_card.dart';

import 'support/golden_fonts.dart';

import 'package:infurnus_driver/core/operations_theme.dart';

const ride = '11111111-1111-4111-8111-111111111111';
http.Response contact([String? phone = '+919876543210']) => http.Response(
  jsonEncode({
    'success': true,
    'data': {'rideId': ride, 'name': 'Actual Customer', 'phone': phone},
  }),
  200,
);

class _Session extends DriverSession {
  _Session(http.Client client) : super(api: ApiService(client: client)) {
    api.accessToken = 'test-credential';
    api.userId = 'driver-user';
    currentTrip = {'id': ride, 'status': 'driver_assigned'};
  }
  @override
  bool get authenticated => api.accessToken != null;
}

Widget app(DriverSession session, {Future<bool> Function(Uri)? launch}) =>
    ChangeNotifierProvider<DriverSession>.value(
      value: session,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RideCustomerContactCard(launcher: launch),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadGoldenFonts);
  test(
    'legacy national customer numbers retain their dialling meaning',
    () async {
      final session = _Session(MockClient((_) async => contact('9876543210')));
      addTearDown(session.dispose);
      expect(
        (await session.customerContactUri('tel')).toString(),
        'tel:9876543210',
      );
    },
  );
  testWidgets(
    'shows the backend customer and launches only tel/sms for that ride',
    (tester) async {
      var requests = 0;
      final session = _Session(
        MockClient((request) async {
          expect(
            request.url.path,
            '/rides/driver/rides/$ride/customer-contact',
          );
          expect(request.headers['authorization'], 'Bearer test-credential');
          requests++;
          return contact();
        }),
      );
      addTearDown(session.dispose);
      await session.refreshCustomerContact();
      final opened = <Uri>[];
      await tester.pumpWidget(
        app(
          session,
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      );
      expect(find.text('Actual Customer'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      for (final label in ['Call', 'Message']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(opened.map((uri) => uri.toString()), [
        'tel:+919876543210',
        'sms:+919876543210',
      ]);
      expect(
        requests,
        3,
      ); // one initial load and one fresh check per explicit action
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'loading, absent number and safe retry error never enable contact actions',
    (tester) async {
      final response = Completer<http.Response>();
      final session = _Session(MockClient((_) => response.future));
      addTearDown(session.dispose);
      final pending = session.refreshCustomerContact();
      await tester.pumpWidget(app(session));
      expect(find.text('Verifying customer contact…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call'))
            .onPressed,
        isNull,
      );
      response.complete(contact(null));
      await pending;
      await tester.pumpAndSettle();
      expect(
        find.text('No phone number is available for this customer.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Message'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'denied revalidation clears the number and never opens a native app',
    (tester) async {
      var denied = false;
      var launches = 0;
      final session = _Session(
        MockClient(
          (_) async => denied
              ? http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'RIDE_CONTACT_UNAVAILABLE',
                      'message': 'Not available',
                    },
                  }),
                  404,
                )
              : contact(),
        ),
      );
      addTearDown(session.dispose);
      await session.refreshCustomerContact();
      await tester.pumpWidget(
        app(
          session,
          launch: (_) async {
            launches++;
            return true;
          },
        ),
      );
      denied = true;
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(find.text('+919876543210'), findsNothing);
      expect(find.text('Retry customer contact'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('coalesces requests and discards late results after cancellation or a user change', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final session = _Session(
      MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    addTearDown(session.dispose);
    final first = session.refreshCustomerContact();
    final duplicate = session.refreshCustomerContact();
    session.busy = true;
    session.handleRideEvent('ride:cancelled', {'rideId': ride});
    response.complete(contact());
    await Future.wait([first, duplicate]);
    expect(requests, 1);
    expect(session.customerContact, isNull);
    session.currentTrip = {'id': ride, 'status': 'cancelled'};
    expect(await session.customerContactUri('sms'), isNull);
  });

  test(
    'all ineligible states and preview sessions issue no contact request',
    () async {
      var requests = 0;
      final session = _Session(
        MockClient((_) async {
          requests++;
          return contact();
        }),
      );
      addTearDown(session.dispose);
      for (final status in [
        'requested',
        'searching',
        'rejected',
        'expired',
        'completed',
        'cancelled',
      ]) {
        session.currentTrip = {'id': ride, 'status': status};
        expect(await session.customerContactUri('tel'), isNull);
      }
      session.currentTrip = {'id': ride, 'status': 'driver_assigned'};
      session.isPreview = true;
      await session.refreshCustomerContact();
      expect(requests, 0);
    },
  );

  testWidgets(
    'unsupported native app reports a safe error; duplicate taps are blocked',
    (tester) async {
      final session = _Session(MockClient((_) async => contact()));
      addTearDown(session.dispose);
      await session.refreshCustomerContact();
      var launches = 0;
      final result = Completer<bool>();
      await tester.pumpWidget(
        app(
          session,
          launch: (_) {
            launches++;
            return result.future;
          },
        ),
      );
      await tester.tap(find.text('Call'));
      await tester.pump();
      await tester.tap(find.text('Call'));
      expect(launches, 1);
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open the dialer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final change in ['logout', 'account', 'ride']) {
    test('late contact response is discarded after $change', () async {
      final response = Completer<http.Response>();
      final session = _Session(MockClient((_) => response.future));
      addTearDown(session.dispose);
      final pending = session.refreshCustomerContact();
      if (change == 'logout') {
        await session.logout();
      } else if (change == 'account') {
        session.api.userId = 'different-driver';
      } else {
        session.currentTrip = {
          'id': 'different-ride',
          'status': 'driver_assigned',
        };
      }
      response.complete(contact());
      await pending;
      expect(session.customerContact, isNull);
    });
  }

  testWidgets(
    'malformed backend contact fails closed without exposing a different ride',
    (tester) async {
      final session = _Session(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'rideId': 'wrong-ride',
                'name': 'Wrong Customer',
                'phone': '+919876543210',
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(session.dispose);
      await session.refreshCustomerContact();
      await tester.pumpWidget(app(session));
      expect(find.text('Wrong Customer'), findsNothing);
      expect(find.text('+919876543210'), findsNothing);
      expect(find.text('Retry customer contact'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('contact actions fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = _Session(MockClient((_) async => contact()));
    addTearDown(session.dispose);
    await session.refreshCustomerContact();
    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: MaterialApp(
          theme: Ops.theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.8),
            ),
            child: RepaintBoundary(
              key: key,
              child: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: RideCustomerContactCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final capture = await boundary.toImage();
      final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
      final out = Directory('../artifacts/driver-contact-20261026')
        ..createSync(recursive: true);
      await File('${out.path}/contact-card-320.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });
}

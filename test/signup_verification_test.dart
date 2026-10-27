import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:convert';

import 'support/golden_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/models/signup_phone.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/auth/otp_verification_screen.dart';
import 'package:infurnus_driver/screens/auth/registration_screen.dart';
import 'package:infurnus_driver/widgets/signup_verification_layout.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('../artifacts/driver-signup-20261026')
      ..createSync(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('login challenge offers signup without claiming OTP delivery', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final session = DriverSession(api: api)
      ..challengeId = 'nonrevealing-challenge';
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          theme: Ops.theme,
          home: const OtpVerificationScreen(),
        ),
      ),
    );
    expect(
      find.textContaining('Login codes are sent only to registered accounts'),
      findsOneWidget,
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.textContaining('code sent to'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.dispose();
  });
  test('signup includes country code without duplicating it or changing explicit international numbers', () {
    expect(normalizeSignupPhone('98765 43210'), '+919876543210');
    expect(normalizeSignupPhone('919876543210'), '+919876543210');
    expect(normalizeSignupPhone('+1 (650) 555-0100'), '+16505550100');
    expect(
      normalizeSignupPhone('6505550100', countryCode: '+1'),
      '+16505550100',
    );
    expect(normalizeSignupPhone(''), '');
    for (final invalid in [
      '123',
      'abc9876543210',
      '09876543210',
      '++919876543210',
      '+91987654321',
    ]) {
      expect(() => normalizeSignupPhone(invalid), throwsFormatException);
    }
  });

  test(
    'signup accepts only confirmed challenge and uses server expiry/cooldown',
    () async {
      var malformed = false;
      final api = ApiService(
        client: MockClient((r) async {
          expect(r.url.path, '/auth/signup');
          expect(jsonDecode(r.body)['phone'], '+919876543210');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': malformed
                  ? {}
                  : {
                      'signupId': 'signup-fixture',
                      'contactType': 'phone',
                      'expiresAt': '2099-01-01T00:00:00Z',
                      'resendAfterSeconds': 90,
                    },
            }),
            201,
          );
        }),
      );
      expect(await api.signup({'phone': '+919876543210'}), 'signup-fixture');
      expect(api.signupOtpExpiresAt, DateTime.utc(2099));
      expect(api.otpResendAfterSeconds, 90);
      malformed = true;
      await expectLater(
        api.signup({'phone': '+919876543210'}),
        throwsA(isA<ApiException>()),
      );
      api.dispose();
    },
  );

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
      'shared signup and OTP presentation fits $width at large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ApiService(
          client: MockClient((_) async => http.Response('{}', 500)),
        );
        final s = DriverSession(api: api);
        s.signupId = 'fixture';
        s.verificationContact = '+919876543210';
        s.verificationResendAt = DateTime.now().add(
          const Duration(seconds: 90),
        );
        final captureKey = GlobalKey();
        Widget app(Widget screen) => ChangeNotifierProvider.value(
          value: s,
          child: MaterialApp(
            theme: Ops.theme,
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.8),
              ),
              child: child!,
            ),
            home: RepaintBoundary(key: captureKey, child: screen),
          ),
        );
        await tester.pumpWidget(app(const RegistrationScreen()));
        expect(find.byType(SignupVerificationLayout), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Sign up with Google'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Sign up with Google'), findsOneWidget);
        await tester.ensureVisible(find.text('Sign up with Google'));
        await tester.pumpAndSettle();
        await capture(tester, captureKey, 'google-signup-$width');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const OtpVerificationScreen()));
        expect(find.byType(SignupVerificationLayout), findsOneWidget);
        expect(find.textContaining('+919876543210'), findsOneWidget);
        final verify = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(verify.onPressed, isNull);
        await tester.enterText(find.byType(TextField), '12345x6');
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '123456',
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await capture(tester, captureKey, 'phone-otp-$width');
        await tester.pumpWidget(const SizedBox());
        s.dispose();
        api.dispose();
      },
    );
  }
}

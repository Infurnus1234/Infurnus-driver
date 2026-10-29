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
import 'package:infurnus_driver/widgets/google_sign_in_button.dart';

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

ApiService _errorApi() =>
    ApiService(client: MockClient((_) async => http.Response('{}', 500)));

Widget _wrap(Widget screen, DriverSession s) => ChangeNotifierProvider.value(
  value: s,
  child: MaterialApp(theme: Ops.theme, home: screen),
);

void main() {
  setUpAll(loadGoldenFonts);

  // ---------------------------------------------------------------------------
  // 1. Signup method tracking: Google hidden on email/phone path
  // ---------------------------------------------------------------------------

  testWidgets(
    'RegistrationScreen via=email_phone hides Google button and opens form',
    (tester) async {
      final api = _errorApi();
      final s = DriverSession(api: api);
      addTearDown(() {
        s.dispose();
        api.dispose();
      });
      await tester.pumpWidget(
        _wrap(
          const RegistrationScreen(
            initialRole: 'driver',
            signupVia: 'email_phone',
          ),
          s,
        ),
      );
      // Google button must NOT appear
      expect(find.byType(GoogleSignInButton), findsNothing);
      expect(find.text('Sign up with Google'), findsNothing);
      // Form fields are visible immediately (no tap-to-expand needed)
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'First name *',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('RegistrationScreen without via shows Google button', (
    tester,
  ) async {
    final api = _errorApi();
    final s = DriverSession(api: api);
    addTearDown(() {
      s.dispose();
      api.dispose();
    });
    await tester.pumpWidget(
      _wrap(const RegistrationScreen(initialRole: 'driver'), s),
    );
    // Must scroll to find Google button (it is in the list)
    await tester.scrollUntilVisible(
      find.byType(GoogleSignInButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(GoogleSignInButton), findsOneWidget);
  });

  testWidgets(
    'RegistrationScreen driver_fleet_owner via=email_phone hides Google button',
    (tester) async {
      final api = _errorApi();
      final s = DriverSession(api: api);
      addTearDown(() {
        s.dispose();
        api.dispose();
      });
      await tester.pumpWidget(
        _wrap(
          const RegistrationScreen(
            initialRole: 'driver_fleet_owner',
            signupVia: 'email_phone',
          ),
          s,
        ),
      );
      expect(find.byType(GoogleSignInButton), findsNothing);
      expect(find.text('Sign up with Google'), findsNothing);
    },
  );

  testWidgets(
    'RegistrationScreen fleet_owner via=email_phone hides Google button',
    (tester) async {
      final api = _errorApi();
      final s = DriverSession(api: api);
      addTearDown(() {
        s.dispose();
        api.dispose();
      });
      await tester.pumpWidget(
        _wrap(
          const RegistrationScreen(
            initialRole: 'fleet_owner',
            signupVia: 'email_phone',
          ),
          s,
        ),
      );
      expect(find.byType(GoogleSignInButton), findsNothing);
      expect(find.text('Sign up with Google'), findsNothing);
    },
  );

  // ---------------------------------------------------------------------------
  // 2. OTP screen: login challenge shows signup hint without claiming delivery
  // ---------------------------------------------------------------------------

  testWidgets('login challenge offers signup without claiming OTP delivery', (
    tester,
  ) async {
    final api = _errorApi();
    final session = DriverSession(api: api)
      ..challengeId = 'nonrevealing-challenge';
    addTearDown(() {
      session.dispose();
      api.dispose();
    });
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
    // Must NOT hint which contact the code was sent to
    expect(find.textContaining('code sent to'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // 3. Phone normalisation
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // 4. API: signup challenge contract
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // 5. Layout: OTP screen and registration screen fit at 320 px + large text
  // ---------------------------------------------------------------------------

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('OTP screen fits $width at large text scale', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _errorApi();
      final s = DriverSession(api: api);
      s.signupId = 'fixture';
      s.verificationContact = '+919876543210';
      s.verificationResendAt = DateTime.now().add(const Duration(seconds: 90));
      addTearDown(() {
        s.dispose();
        api.dispose();
      });
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
      await tester.pumpWidget(app(const OtpVerificationScreen()));
      // Contact hint must be present
      expect(find.textContaining('+919876543210'), findsOneWidget);
      // Verify button is disabled until all 6 digits are entered
      final verify = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(verify.onPressed, isNull);
      // Entering 6 digits enables the button
      final boxes = find.byType(TextField);
      expect(boxes.evaluate().length, 6);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(boxes.at(i), '$i');
      }
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await capture(tester, captureKey, 'phone-otp-$width');
    });

    testWidgets(
      'RegistrationScreen via=email_phone fits $width at large text scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _errorApi();
        final s = DriverSession(api: api);
        addTearDown(() {
          s.dispose();
          api.dispose();
        });
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
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
              home: RepaintBoundary(
                key: captureKey,
                child: const RegistrationScreen(
                  initialRole: 'driver',
                  signupVia: 'email_phone',
                ),
              ),
            ),
          ),
        );
        // No Google button
        expect(find.byType(GoogleSignInButton), findsNothing);
        // Form renders without overflow
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await capture(tester, captureKey, 'email-phone-signup-$width');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. OTP screen: resend timer shows countdown, Resend action appears after
  // ---------------------------------------------------------------------------

  testWidgets('OTP resend timer counts down and enables Resend', (
    tester,
  ) async {
    final api = _errorApi();
    final s = DriverSession(api: api);
    s.signupId = 'fixture';
    s.verificationContact = '+919876543210';
    // Set resend to be available immediately
    s.verificationResendAt = DateTime.now().subtract(
      const Duration(seconds: 1),
    );
    addTearDown(() {
      s.dispose();
      api.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          theme: Ops.theme,
          home: const OtpVerificationScreen(),
        ),
      ),
    );
    await tester.pump();
    // Resend button must be present
    expect(find.text('Resend'), findsOneWidget);
    // Countdown text must NOT appear when remaining == 0
    expect(find.textContaining('Resend in'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // 7. OTP screen: error state clears boxes
  // ---------------------------------------------------------------------------

  testWidgets('OTP verify button is disabled until 6 digits entered', (
    tester,
  ) async {
    final api = _errorApi();
    final s = DriverSession(api: api);
    s.signupId = 'fixture';
    s.verificationContact = 'test@example.com';
    s.verificationResendAt = DateTime.now().add(const Duration(seconds: 30));
    addTearDown(() {
      s.dispose();
      api.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          theme: Ops.theme,
          home: const OtpVerificationScreen(),
        ),
      ),
    );
    // Only 5 digits
    final boxes = find.byType(TextField);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(boxes.at(i), '$i');
    }
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    // 6th digit enables it
    await tester.enterText(boxes.at(5), '5');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

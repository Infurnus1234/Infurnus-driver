import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/screens/auth/driver_onboarding_screen.dart';
import 'package:infurnus_driver/screens/auth/verification_status_screen.dart';

import 'guided_onboarding_test.dart' show FixtureSession;

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('infurnus/maps'),
          (_) async => false,
        );
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter') as Map;
    final root = Directory.fromUri(
      config.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final fonts = root.uri.resolve('bin/cache/artifacts/material_fonts/');
    final text = FontLoader('Roboto')
      ..addFont(
        File.fromUri(fonts.resolve('roboto-regular.ttf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File.fromUri(fonts.resolve('materialicons-regular.otf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await text.load();
    await icons.load();
  });

  for (final stage in [
    'photo',
    'sources',
    'licence',
    'summary',
    'skip',
    'pending-dashboard',
  ]) {
    testWidgets('guided onboarding visual $stage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = FixtureSession();
      addTearDown(session.dispose);
      if (stage == 'skip') {
        session.documentRules = [
          const DocumentRule(
            'profile_photo',
            required: true,
            onboardingDeferrable: true,
          ),
          const DocumentRule('driver_license', required: true),
        ];
      }
      if (stage == 'pending-dashboard') {
        session.api.role = 'driver';
        session.onboardingReceipt = {
          'receipt_id': 'fixture',
          'dashboardAccessible': true,
          'deferred_codes': ['vehicle'],
        };
        expect(session.dashboardAllowed, isTrue);
        expect(session.operationalAllowed, isFalse);
      }
      if (stage == 'licence') {
        session.documents.add({
          'id': 'photo',
          'documentType': 'profile_photo',
          'verificationStatus': 'pending',
        });
      }
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: Ops.theme,
            home: stage == 'pending-dashboard'
                ? const OperationsDashboard()
                : stage == 'summary'
                ? const VerificationStatusScreen()
                : DriverOnboardingScreen(
                    initialTask: stage == 'licence' ? 'licence' : null,
                    picker: (_, _) async => [],
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (stage == 'sources') {
        await tester.tap(find.text('Choose source'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/onboarding-$stage-390.png'),
      );
    });
  }
}

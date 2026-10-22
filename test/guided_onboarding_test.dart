import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/models/onboarding_journey.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/auth/driver_onboarding_screen.dart';
import 'package:infurnus_driver/screens/auth/guided_document_capture.dart';
import 'package:infurnus_driver/screens/auth/verification_status_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';

final image = DocumentFile(
  'fixture.png',
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGNQKFgARwzEcQDmQxMBTnKOxAAAAABJRU5ErkJggg==',
  ),
  'image/png',
);

class FixtureSession extends DriverSession {
  bool failUpload = false;
  int uploads = 0;
  FixtureSession() {
    onboardingLoaded = true;
    account = {'firstName': 'Fixture', 'lastName': 'Driver'};
    profile = {
      'id': 'profile',
      'licenseNumber': 'FIXTURE',
      'licenseExpiry': '2099-12-31',
      'verificationStatus': 'pending',
    };
    documentRules = [
      const DocumentRule('profile_photo', required: true),
      const DocumentRule('driver_license', required: true),
      const DocumentRule('vehicle_rc', required: true),
    ];
  }
  @override
  bool get authenticated => true;
  @override
  Future<bool> uploadDocument(
    DocumentRule rule,
    List<DocumentFile> files,
    Map<String, String> metadata,
  ) async {
    uploads++;
    if (failUpload) {
      error = 'Fixture connection failed';
      notifyListeners();
      return false;
    }
    documents.removeWhere((d) => d['documentType'] == rule.code);
    documents.add({
      'id': rule.code,
      'documentType': rule.code,
      'verificationStatus': 'pending',
      'documentMetadata': metadata,
    });
    error = null;
    notifyListeners();
    return true;
  }
}

Widget host(DriverSession session, Widget screen, {double scale = 1}) =>
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(
        theme: Ops.theme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: screen,
        ),
      ),
    );
Future<void> pick(WidgetTester tester, String label) async {
  final source = label.toLowerCase().contains('gallery') ? 'Gallery' : 'Camera';
  final trigger = find.text('Choose source').evaluate().isNotEmpty
      ? 'Choose source'
      : 'Replace or add pages';
  await tester.ensureVisible(find.text(trigger));
  await tester.tap(find.text(trigger));
  await tester.pumpAndSettle();
  await tester.tap(find.text(source));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pumpAndSettle();
}

void main() {
  test('server state restores the first correction and never equates pending with approval', () {
    final s = FixtureSession();
    addTearDown(s.dispose);
    var tasks = OnboardingJourney.tasks(s);
    expect(tasks[OnboardingJourney.resume(tasks, s)].id, 'profile_photo');
    s.documents.add({
      'id': 'photo',
      'documentType': 'profile_photo',
      'verificationStatus': 'pending',
    });
    expect(tasks[OnboardingJourney.resume(tasks, s)].id, 'licence');
    expect(s.dashboardAllowed, isFalse);
    s.documents.first['verificationStatus'] = 'rejected';
    expect(tasks[OnboardingJourney.resume(tasks, s)].id, 'profile_photo');
    s.profile = null;
    tasks = OnboardingJourney.tasks(s);
    expect(tasks.first.id, 'licence');
    expect(tasks.where((t) => t.id == 'fleet'), isEmpty);
    s.api.role = 'driver_fleet_owner';
    expect(
      OnboardingJourney.tasks(s).where((t) => t.id == 'fleet'),
      hasLength(1),
    );
  });
  testWidgets(
    'local selection and failure do not advance; retry saves then shows licence',
    (tester) async {
      final s = FixtureSession()..failUpload = true;
      addTearDown(s.dispose);
      await tester.pumpWidget(
        host(s, DriverOnboardingScreen(picker: (_, _) async => [image])),
      );
      await pick(tester, 'Choose from gallery');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GuidedDocumentCapture>(find.byType(GuidedDocumentCapture))
            .rule
            .code,
        'profile_photo',
      );
      expect(s.uploads, 0);
      await tester.runAsync(() async {
        await tester.tap(find.text('Upload & continue'));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GuidedDocumentCapture>(find.byType(GuidedDocumentCapture))
            .rule
            .code,
        'profile_photo',
      );
      await tester.scrollUntilVisible(
        find.textContaining('Fixture connection failed'),
        150,
      );
      expect(find.textContaining('Fixture connection failed'), findsOneWidget);
      expect(s.uploads, 1);
      expect(
        tester
            .widget<GuidedDocumentCapture>(find.byType(GuidedDocumentCapture))
            .draft
            .files,
        hasLength(1),
      );
      s.failUpload = false;
      await tester.runAsync(() async {
        await tester.tap(find.text('Upload & continue'));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pumpAndSettle();
      expect(find.text('Your driving licence'), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
      expect(s.uploads, 2);
      expect(s.dashboardAllowed, isFalse);
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      expect(find.text('Saved on server: Pending review'), findsOneWidget);
      expect(find.text('Selected locally — page 1'), findsNothing);
    },
  );
  testWidgets(
    'picker cancellation retains draft; camera retake replaces photo',
    (tester) async {
      final draft = CaptureDraft();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuidedDocumentCapture(
                rule: const DocumentRule('profile_photo'),
                draft: draft,
                changed: () {},
                picker: (_, _) async => ++calls == 2 ? [] : [image],
              ),
            ),
          ),
        ),
      );
      await pick(tester, 'Take photo');
      await tester.pumpAndSettle();
      expect(draft.files, hasLength(1));
      await pick(tester, 'Retake photo');
      await tester.pumpAndSettle();
      expect(draft.files, hasLength(1));
      await pick(tester, 'Retake photo');
      await tester.pumpAndSettle();
      expect(draft.files, hasLength(1));
      await tester.ensureVisible(find.byTooltip('Remove page 1'));
      await tester.tap(find.byTooltip('Remove page 1'));
      await tester.pumpAndSettle();
      expect(draft.files, isEmpty);
    },
  );
  testWidgets(
    'permission denial offers settings and another source without advancing',
    (tester) async {
      final draft = CaptureDraft();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuidedDocumentCapture(
                rule: const DocumentRule('profile_photo'),
                draft: draft,
                changed: () {},
                picker: (_, _) async => throw PlatformException(
                  code: 'camera_access_denied_without_prompt',
                ),
              ),
            ),
          ),
        ),
      );
      await pick(tester, 'Take photo');
      await tester.pumpAndSettle();
      expect(draft.files, isEmpty);
      expect(find.text('Open app settings'), findsOneWidget);
      expect(find.text('Choose source'), findsOneWidget);
    },
  );
  testWidgets(
    'summary renders requirements once even with repeated approval requests',
    (tester) async {
      final s = FixtureSession();
      addTearDown(s.dispose);
      s.approvals = List.generate(
        3,
        (_) => {
          'target_type': 'vehicle',
          'target_id': 'same',
          'request_type': 'vehicle_verification',
          'status': 'PENDING',
        },
      );
      await tester.pumpWidget(host(s, const VerificationStatusScreen()));
      expect(find.text('Verification summary'), findsOneWidget);
      expect(find.text('Your profile photo'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Connect your vehicle'), 180);
      expect(find.text('Connect your vehicle'), findsOneWidget);
      expect(find.text('vehicle verification'), findsNothing);
    },
  );
  testWidgets(
    '320px photo task supports large text without layout exceptions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = FixtureSession();
      addTearDown(s.dispose);
      await tester.pumpWidget(
        host(s, DriverOnboardingScreen(picker: (_, _) async => []), scale: 1.8),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Upload & continue'), findsOneWidget);
    },
  );
}

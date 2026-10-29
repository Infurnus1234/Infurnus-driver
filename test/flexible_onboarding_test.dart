import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/models/onboarding_journey.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/auth/driver_onboarding_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';

import 'package:infurnus_driver/services/session_store.dart';

import 'guided_onboarding_test.dart' show FixtureSession, host;

class PendingSession extends DriverSession {
  PendingSession(ApiService api)
    : super(api: api, onboardingDraftStore: MemorySessionStore()) {
    api.accessToken = 'fixture-token';
    api.role = 'driver';
    api.userId = 'fixture-user';
    onboardingLoaded = true;
    profile = {
      'id': 'profile',
      'licenseNumber': 'FIXTURE',
      'licenseExpiry': '2099-12-31',
      'verificationStatus': 'pending',
    };
    documentRules = [
      const DocumentRule(
        'profile_photo',
        required: true,
        onboardingDeferrable: true,
      ),
      const DocumentRule('driver_license', required: true),
    ];
    documents = [
      {
        'id': 'licence',
        'documentType': 'driver_license',
        'verificationStatus': 'pending',
      },
    ];
    clearLocalDeferrals();
  }
  @override
  bool get authenticated => true;
}

void main() {
  test('successful server receipt survives refresh failure without claiming approval', () async {
    var submissions = 0;
    final s = PendingSession(
      ApiService(
        client: MockClient((r) async {
          if (r.url.path == '/provider/approval-requests') {
            submissions++;
            expect(jsonDecode(r.body), {
              'requestType': 'onboarding_submission',
            });
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'receipt_id': 'receipt',
                  'dashboardAccessible': true,
                  'deferred_codes': ['vehicle'],
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'UNAVAILABLE', 'message': 'Fixture offline'},
            }),
            503,
          );
        }),
      ),
    );
    addTearDown(s.dispose);
    expect(await s.submitOnboarding(), isTrue);
    expect(submissions, 1);
    expect(s.dashboardAllowed, isTrue);
    expect(s.operationalAllowed, isFalse);
    expect(s.profile!['verificationStatus'], 'pending');
    expect(s.documents.single['id'], 'licence');
  });
  test(
    'failed batch keeps uploaded documents and retries the same request',
    () async {
      var attempts = 0;
      final s = PendingSession(
        ApiService(
          client: MockClient((r) async {
            if (r.url.path == '/provider/approval-requests') attempts++;
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'UNAVAILABLE', 'message': 'Retry submission'},
              }),
              503,
            );
          }),
        ),
      );
      addTearDown(s.dispose);
      expect(await s.submitOnboarding(), isFalse);
      expect(await s.submitOnboarding(), isFalse);
      expect(attempts, 2);
      expect(s.dashboardAllowed, isFalse);
      expect(s.documents.single['id'], 'licence');
    },
  );
  test('server deferral does not fabricate document completion and resume bypasses skipped step', () async {
    final s = PendingSession(
      ApiService(
        client: MockClient((r) async {
          expect(jsonDecode(r.body), {'defer': 'vehicle'});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'dashboardAccessible': false,
                'deferred_codes': ['vehicle'],
              },
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(s.dispose);
    s.documents.add({
      'id': 'photo',
      'documentType': 'profile_photo',
      'verificationStatus': 'pending',
    });
    s.documentRules = [const DocumentRule('driver_license', required: true)];
    expect(await s.deferStep('vehicle'), isTrue);
    final tasks = OnboardingJourney.tasks(s);
    expect(
      OnboardingJourney.satisfied(
        tasks.firstWhere((t) => t.id == 'vehicle'),
        s,
      ),
      isFalse,
    );
    expect(tasks[OnboardingJourney.resume(tasks, s)].id, 'summary');
    expect(s.documents.length, 2);
    expect(s.canDefer('driver_license'), isFalse);
  });
  test(
    'missing progress endpoint saves skip locally without granting approval',
    () async {
      var calls = 0;
      final s = PendingSession(
        ApiService(
          client: MockClient((r) async {
            calls++;
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'NOT_FOUND', 'message': 'Unavailable'},
              }),
              404,
            );
          }),
        ),
      );
      addTearDown(s.dispose);
      expect(await s.deferStep('vehicle'), isTrue);
      expect(s.deferredSteps, contains('vehicle'));
      expect(s.dashboardAllowed, isFalse);
      expect(s.operationalAllowed, isFalse);
      expect(s.onboardingReceipt, isNull);
      expect(await s.resumeStep('vehicle'), isTrue);
      expect(s.deferredSteps, isNot(contains('vehicle')));
      expect(calls, 1);
      expect(await s.deferStep('driver_license'), isFalse);
      expect(calls, 1);
    },
  );
  testWidgets('tap Skip for now advances after progress endpoint 404', (
    tester,
  ) async {
    final s = PendingSession(
      ApiService(client: MockClient((r) async => http.Response('{}', 404))),
    );
    s.documents.clear();
    addTearDown(s.dispose);
    await tester.pumpWidget(host(s, const DriverOnboardingScreen()));
    await tester.tap(find.text('Skip for now').first);
    await tester.pumpAndSettle();
    expect(s.deferredSteps, contains('profile_photo'));
    expect(find.text('Your driving licence'), findsOneWidget);
    expect(s.dashboardAllowed, isFalse);
  });
  test('server failure does not silently record a skip', () async {
    final s = PendingSession(
      ApiService(client: MockClient((r) async => http.Response('{}', 503))),
    );
    addTearDown(s.dispose);
    expect(await s.deferStep('vehicle'), isFalse);
    expect(s.deferredSteps, isEmpty);
  });
  testWidgets(
    'licence cannot be skipped; permitted document exposes Skip for now',
    (tester) async {
      final s = FixtureSession();
      addTearDown(s.dispose);
      s.documentRules = [
        const DocumentRule(
          'profile_photo',
          required: true,
          onboardingDeferrable: true,
        ),
        const DocumentRule('driver_license', required: true),
      ];
      await tester.pumpWidget(host(s, const DriverOnboardingScreen()));
      expect(find.text('Skip for now'), findsOneWidget);
      await tester.pumpWidget(
        host(
          s,
          const DriverOnboardingScreen(
            key: ValueKey('licence'),
            initialTask: 'driver_license',
          ),
        ),
      );
      expect(find.text('Skip for now'), findsNothing);
    },
  );
}

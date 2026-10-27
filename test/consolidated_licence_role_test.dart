import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infurnus_driver/models/onboarding_journey.dart';
import 'package:infurnus_driver/screens/auth/driver_onboarding_screen.dart';
import 'package:infurnus_driver/screens/auth/role_selection_screen.dart';

import 'guided_onboarding_test.dart' show FixtureSession, host, image, pick;

class _LicenceSession extends FixtureSession {
  int saves = 0;
  @override
  Future<bool> saveProfile(Map<String, dynamic> input) async {
    saves++;
    profile = {...?profile, ...input};
    notifyListeners();
    return true;
  }
}

void main() {
  for (final role in ProviderRoleCards.options) {
    testWidgets(
      '${role.$2} selection retains registration intent at narrow width',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          initialLocation: '/role-selection',
          routes: [
            GoRoute(
              path: '/role-selection',
              builder: (_, _) => const RoleSelectionScreen(),
            ),
            GoRoute(
              path: '/register',
              builder: (_, s) => Scaffold(
                body: Text('Registration ${s.uri.queryParameters['role']}'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        final session = DriverSession();
        addTearDown(session.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: session,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Continue'), 200);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(
          find.text('Select an account type to continue.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text(role.$2));
        await tester.tap(find.text(role.$2));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Continue'), 200);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Registration ${role.$1}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'licence details and photo use one page and one upload across forward/back navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = _LicenceSession();
      addTearDown(s.dispose);
      s.documents.add({
        'id': 'photo',
        'documentType': 'profile_photo',
        'verificationStatus': 'pending',
      });
      final tasks = OnboardingJourney.tasks(s);
      expect(
        tasks.where((t) => t.rule?.code == 'driver_license'),
        hasLength(1),
      );
      expect(
        tasks.any((t) => t.id == 'setup' || t.id == 'driver_license'),
        isFalse,
      );
      await tester.pumpWidget(
        host(
          s,
          DriverOnboardingScreen(
            initialTask: 'licence',
            picker: (_, _) async => [image],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Driving licence number *'), findsOneWidget);
      expect(find.text('Licence expiry (YYYY-MM-DD) *'), findsOneWidget);
      expect(find.text('Choose source'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add the required licence photo or pages before continuing.'),
        findsOneWidget,
      );
      expect(s.uploads, 0);
      await pick(tester, 'Gallery');
      await tester.runAsync(() async {
        await tester.tap(find.text('Continue'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Connect your vehicle'), findsOneWidget);
      expect(s.uploads, 1);
      expect(s.saves, 0);
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      expect(find.text('Your driving licence'), findsOneWidget);
      expect(find.text('FIXTURE'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(s.uploads, 1);
    },
  );
}

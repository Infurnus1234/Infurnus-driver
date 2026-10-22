import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/screens/auth/verification_status_screen.dart';
import 'package:infurnus_driver/screens/driver/vehicle_assignment_screen.dart';

import 'guided_onboarding_test.dart' show FixtureSession;

void main() {
  testWidgets(
    'deferred Driver can return to verification and vehicle setup while revenue stays blocked',
    (tester) async {
      final session = FixtureSession()
        ..roleEnrolment = {'dashboardAccessible': true, 'setupDeferred': true};
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      appRouter.go('/verification-status');
      await tester.pumpAndSettle();
      expect(find.byType(VerificationStatusScreen), findsOneWidget);
      expect(session.operationalAllowed, false);
      appRouter.go('/driver/assignment');
      await tester.pumpAndSettle();
      expect(find.byType(VehicleAssignmentScreen), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
      appRouter.go('/driver/earnings');
      // Router completion is independent of the dashboard platform-map loader.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/driver/dashboard',
      );
      expect(find.text('Net ledger earnings'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

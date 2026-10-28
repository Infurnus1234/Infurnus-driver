import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/app_state.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';
import 'package:infurnus_driver/widgets/account_details_card.dart';
import 'package:infurnus_driver/core/theme.dart';
import 'package:infurnus_driver/router/app_router.dart';

class TestDriverSession extends DriverSession {
  TestDriverSession({required ApiService api}) : super(api: api);

  @override
  bool get authenticated => true;

  void updateTestVerificationStatus(String status) {
    profile = {...?profile, 'verificationStatus': status};
    notifyListeners();
  }
}

void main() {
  setUpAll(() {
    InfurnusTheme.isTesting = true;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('AccountScreen uses real appRouter, shows profile items, navigates to personal-details with AccountDetailsCard, and legacy profile-photo redirects', (tester) async {
    final api = ApiService(
      client: MockClient((r) async {
        if (r.url.path == '/provider/account' || r.url.path == '/rides/driver/profile') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'drv-1',
                'firstName': 'Driver',
                'lastName': 'Account',
                'phone': '+919876543210',
                'email': 'driver@infurnus.com',
                'verificationStatus': 'VERIFIED',
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      }),
    );
    api.accessToken = 'test-token';
    api.userId = 'drv-1';
    api.role = 'driver';
    api.providerMode = 'driver';

    final session = TestDriverSession(api: api);
    session.restoring = false;
    session.restorationNeedsRetry = false;
    session.documentRules = [];
    session.applications = [];
    session.onboardingReceipt = {'dashboardAccessible': true};
    session.roleEnrolment = {
      'role': 'driver',
      'dashboardAccessible': true,
      'operationalAllowed': true,
    };
    session.profile = {'verificationStatus': 'VERIFIED'};
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider<DriverSession>.value(value: session),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    appRouter.go('/profile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Status: VERIFIED'), findsOneWidget);

    // Test verification status colors
    Future<void> checkStatusColor(String status, Color expectedColor) async {
      session.updateTestVerificationStatus(status);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final textWidget = tester.widget<Text>(find.text('Status: $status'));
      expect(textWidget.style?.color, expectedColor);
    }

    await checkStatusColor('UNVERIFIED', InfurnusTheme.warningAmber);
    await checkStatusColor('PENDING', InfurnusTheme.warningAmber);
    await checkStatusColor('VERIFIED', InfurnusTheme.primaryGreen);
    await checkStatusColor('APPROVED', InfurnusTheme.primaryGreen);
    await checkStatusColor('REJECTED', InfurnusTheme.dangerRed);

    // Negative assertions: removed items must NOT be found
    expect(find.text('Driver Mode'), findsNothing);
    expect(find.text('Profile photo'), findsNothing);
    expect(find.text('Vehicles & documents'), findsNothing);
    expect(find.text('Help & support'), findsNothing);

    // Test tapping header card navigates to /personal-details and renders PersonalInformationScreen & AccountDetailsCard
    await tester.tap(find.text('Driver Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PersonalInformationScreen), findsOneWidget);
    expect(find.byType(AccountDetailsCard), findsOneWidget);

    // Test legacy /profile-photo redirects away from /profile-photo to landingPath
    appRouter.go('/profile-photo');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, session.landingPath);
  });
}

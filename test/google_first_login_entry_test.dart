import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/auth/login_screen.dart';
import 'package:infurnus_driver/widgets/google_sign_in_button.dart';

class LoginEntryFixture extends DriverSession {
  LoginEntryFixture()
    : super(
        api: ApiService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'NOT_FOUND'},
              }),
              404,
            ),
          ),
        ),
      );
  bool signedIn = false, signupIntent = false;
  String? selectedRole, token;
  @override
  bool get authenticated => signedIn;
  @override
  String get landingPath => signedIn ? '/role-selection' : '/login';
  @override
  Future<bool> authenticateGoogle(
    String idToken, {
    bool signup = false,
    String? providerRole,
    String? accountRole,
  }) async {
    token = idToken;
    signupIntent = signup;
    selectedRole = providerRole;
    signedIn = true;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets(
    'actual login Google action resolves the account before choosing its role',
    (tester) async {
      final s = LoginEntryFixture();
      addTearDown(s.dispose);
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/role-selection',
            builder: (_, _) =>
                const Scaffold(body: Text('Authenticated role selection')),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: s,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      final button = tester.widget<GoogleSignInButton>(
        find.byType(GoogleSignInButton),
      );
      expect(button.label, 'Continue with Google');
      // Exercise the actual screen callback; native Google account selection is manual.
      await button.onIdToken('fixture-id-token');
      await tester.pumpAndSettle();
      expect(s.signupIntent, true);
      expect(s.selectedRole, isNull);
      expect(s.token, 'fixture-id-token');
      expect(find.text('Authenticated role selection'), findsOneWidget);
    },
  );
}

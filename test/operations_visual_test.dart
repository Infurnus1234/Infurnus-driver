import 'support/golden_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';

void main() {
  setUpAll(() async {
    await loadGoldenFonts();
  });
  testWidgets('account supports narrow device and large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = DriverSession();
    session.account = {'firstName': 'Driver', 'lastName': 'Account'};
    session.profile = {'verificationStatus': 'pending'};
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          theme: Ops.theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.8),
            ),
            child: const AccountScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AccountScreen),
      matchesGoldenFile('../docs/operations-account-320.png'),
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}

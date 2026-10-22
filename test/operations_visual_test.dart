import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';

void main() {
  setUpAll(() async {
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

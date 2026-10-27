import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/widgets/reference_components.dart';

import 'support/golden_fonts.dart';

void main() {
  setUpAll(loadGoldenFonts);
  testWidgets('full logo loads in narrow headers and preserves driver avatar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(
              title: const InfurnusBrand(name: 'Driver'),
              actions: const [Icon(Icons.notifications_none)],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    final rendered = tester.renderObject<RenderImage>(find.byType(RawImage));
    expect(rendered.image, isNotNull);
    expect(rendered.image!.width, 1217);
    expect(rendered.image!.height, 1280);
    await tester.pump(const Duration(milliseconds: 100));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final capture = await boundary.toImage();
      final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
      await File('../artifacts/logo-replacement-20261026/driver-header-320.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}

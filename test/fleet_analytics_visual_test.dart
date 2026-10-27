import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/fleet_revenue_screen.dart';

import 'fleet_analytics_test.dart' as fixtures;
import 'support/golden_fonts.dart';

void main() {
  setUpAll(loadGoldenFonts);
  for (final width in [320.0, 800.0]) {
    testWidgets(
      'analytics uses existing theme without overflow at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = DriverSession(
          api: ApiService(
            client: MockClient(
              (r) async => http.Response(
                jsonEncode({'success': true, 'data': fixtures.report()}),
                200,
              ),
            ),
          ),
        );
        addTearDown(session.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: session,
            child: MaterialApp(
              theme: Ops.theme,
              home: RepaintBoundary(
                key: const Key('analytics-capture'),
                child: Scaffold(
                  appBar: AppBar(title: const Text('Fleet reports')),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MediaQuery(
                        data: MediaQueryData(
                          textScaler: TextScaler.linear(width == 320 ? 1.4 : 1),
                        ),
                        child: const FleetRevenuePanel(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_FLEET_ANALYTICS'] == 'true') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('analytics-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '../artifacts/fleet-analytics-20261023/analytics-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}

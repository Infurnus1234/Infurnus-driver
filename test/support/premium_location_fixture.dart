import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../recording_maps.dart';

void configureOperatingMap() {
  final previous = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = RecordingMaps();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
}

Future<void> selectTestOperatingLocation(
  WidgetTester tester, {
  String address = 'Motihari Bihar',
}) async {
  final field = find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.labelText == 'Operating location in Bihar *',
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, address);
  await tester.pump();
  await tester.ensureVisible(find.text('Find operating location'));
  await tester.tap(find.text('Find operating location'));
  await tester.pumpAndSettle();
}

const testOperatingLocation = {
  'address': 'Patna Bihar',
  'latitude': 25.6,
  'longitude': 85.1,
};

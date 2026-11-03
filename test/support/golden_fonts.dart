import 'dart:io';

import 'package:flutter/services.dart';
import 'package:infurnus_driver/core/theme.dart';

// Checked-in SDK font fixtures keep visual baselines independent of host caches.
Future<void> loadGoldenFonts() async {
  InfurnusTheme.isTesting = true;

  final text = FontLoader('Roboto')
    ..addFont(
      File('test/fixtures/fonts/roboto-regular.ttf')
          .readAsBytes()
          .then(ByteData.sublistView),
    );
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('test/fixtures/fonts/materialicons-regular.otf')
          .readAsBytes()
          .then(ByteData.sublistView),
    );
  await Future.wait([text.load(), icons.load()]);
}

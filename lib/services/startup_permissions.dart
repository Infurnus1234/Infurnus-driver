import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

Future<void> requestStartupLocation() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  const storage = FlutterSecureStorage();
  if (await storage.read(key: 'startup_location_requested') == 'true') return;
  await storage.write(key: 'startup_location_requested', value: 'true');
  if (await Geolocator.checkPermission() == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }
}

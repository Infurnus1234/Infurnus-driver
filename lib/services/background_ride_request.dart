import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_store.dart';
import 'ride_request_presentation.dart';

bool isDriverOffer(Map data) =>
    const ['ride.created', 'driver.offer'].contains(data['type']) &&
    data['rideId'] is String;

/// Reads the current bearer only. Never rotates a shared refresh token from a background isolate.
/// Missing/expired credentials fall back to the normal notification and authenticated app restore.
Future<bool> presentBackgroundOffer(
  Map<String, dynamic> data, {
  SessionStore? store,
  http.Client? transport,
  RideRequestBridge? bridge,
}) async {
  final raw = await (store ?? SecureSessionStore()).read();
  if (raw == null) return true;
  final saved = jsonDecode(raw) as Map;
  if (!['driver', 'driver_fleet_owner'].contains(saved['role']) ||
      saved['providerMode'] == 'fleet_owner') {
    return true;
  }
  final client = transport ?? http.Client();
  try {
    final response = await client
        .get(
          Uri.parse('${ApiService.baseUrl}/rides/driver/available'),
          headers: {'Authorization': 'Bearer ${saved['accessToken']}'},
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map;
    final rows = body['data'];
    if (rows is! List) return false;
    final row = rows
        .cast<Map>()
        .where((r) => r['id'] == data['rideId'])
        .firstOrNull;
    if (row == null) {
      return true; // Expired, revoked or assigned elsewhere: no stale popup.
    }
    final offer = Map<String, dynamic>.from(row)
      ..['_receivedAt'] = DateTime.now().toIso8601String();
    if (offerRemaining(offer) <= Duration.zero) return true;
    return await (bridge ?? RideRequestBridge()).present(offer);
  } finally {
    if (transport == null) client.close();
  }
}

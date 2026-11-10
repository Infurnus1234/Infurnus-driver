import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Every surface uses the authenticated offer deadline, adjusted to the server clock.
Duration offerRemaining(Map ride, {DateTime? now}) {
  final local = now ?? DateTime.now();
  final expiry = DateTime.tryParse(ride['dispatchExpiresAt']?.toString() ?? '');
  if (expiry == null) return Duration.zero;
  final server = DateTime.tryParse(ride['serverTime']?.toString() ?? '');
  final received = DateTime.tryParse(ride['_receivedAt']?.toString() ?? '');
  final effective = server != null && received != null
      ? server.add(local.difference(received))
      : local;
  return expiry.difference(effective);
}

String offerKey(Map ride) => '${ride['id']}:${ride['dispatchExpiresAt']}';
String rideRequestRoute(String rideId) => Uri(
  path: '/driver/ride-requests',
  queryParameters: {'offer': rideId},
).toString();
String requestSector(Map ride) =>
    const {
      'passenger': 'Rental',
      'rental': 'Rental',
      'logistics': 'Logistics',
      'premium': 'Premium',
      'service': 'Service',
    }[ride['sector']] ??
    'Ride';
String requestVehicle(Map ride) =>
    ride['vehicleName']?.toString() ??
    ride['vehicleDetails']?['name']?.toString() ??
    ride['vehicleCategory']?.toString().replaceAll('_', ' ') ??
    'Vehicle';
num? requestDistance(Map ride) =>
    (ride['rideInformation']?['totalDistance']?['meters'] ??
            ride['rideInformation']?['distance']?['meters'] ??
            ride['bookingDistanceMeters'] ??
            ride['distanceMeters'])
        as num?;
num? requestDuration(Map ride) =>
    (ride['rideInformation']?['duration']?['seconds'] ??
            ride['durationSeconds'] ??
            ride['estimatedDurationSeconds'] ??
            ride['bookingDurationSeconds'])
        as num?;
String? driverDropAddress(Map ride) {
  if (ride['sector'] == 'logistics' &&
      !(ride['pinVerified'] == true &&
          ['in_progress', 'completed', 'cancelled'].contains(ride['status']))) {
    return ride['destinationDistrict']?.toString();
  }
  return ride['destinationAddress']?.toString();
}

Map<String, dynamic> nativeOffer(Map<String, dynamic> ride) {
  final distance = requestDistance(ride), duration = requestDuration(ride);
  final fare =
      ride['rideInformation']?['fare']?['amount'] ?? ride['fareEstimate'];
  return {
    'key': offerKey(ride),
    'rideId': ride['id'],
    'inApp': ride['_presentInApp'] == true,
    'deadline': DateTime.now().add(offerRemaining(ride)).millisecondsSinceEpoch,
    'pickup': ride['pickupAddress'] ?? 'Pickup details available in app',
    // Never reveal a drop withheld by the existing backend's pre-PIN policy.
    'drop': driverDropAddress(ride) ?? 'Available after PIN verification',
    'sectorLabel': requestSector(ride), 'vehicle': requestVehicle(ride),
    'distance': distance == null
        ? 'Distance unavailable'
        : '${(distance / 1000).toStringAsFixed(1)} km',
    'duration': duration == null
        ? 'ETA unavailable'
        : '~ ${(duration / 60).ceil()} min',
    if (fare is num)
      'fare': '₹${fare.toStringAsFixed(fare == fare.roundToDouble() ? 0 : 2)}',
  };
}

class RideRequestBridge {
  final bool? android;
  RideRequestBridge({this.android});
  static const _channel = MethodChannel('infurnus/ride_requests');
  bool get supported => android ?? (!kIsWeb && Platform.isAndroid);
  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> initialize(VoidCallback onAction) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'actionAvailable') onAction();
    });
    await _call('ready');
  }

  Future<Map?> status() => _call<Map>('status');
  Future<void> requestOverlayPermission() async {
    await _call('permission');
  }

  Future<void> requestNotificationPermission() async {
    await _call('notificationPermission');
  }

  Future<bool> present(Map<String, dynamic> ride) async =>
      await _call<bool>('present', nativeOffer(ride)) ?? false;
  Future<bool> notifyOffer(String rideId, String expiresAt) async {
    final deadline = DateTime.tryParse(expiresAt);
    if (deadline == null || !deadline.isAfter(DateTime.now())) return true;
    return await _call<bool>('notifyOffer', {
          'key': '$rideId:$expiresAt',
          'rideId': rideId,
          'deadline': deadline.millisecondsSinceEpoch,
        }) ??
        false;
  }

  Future<void> dismiss() async {
    await _call('dismiss');
  }

  Future<void> dismissOffer(String rideId, {bool invalidate = true}) async {
    await _call('dismissOffer', {'rideId': rideId, 'invalidate': invalidate});
  }

  Future<void> clear() async {
    await _call('clear');
  }

  Future<Map<String, dynamic>?> takeAction() async {
    final raw = await _call<String>('takeAction');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

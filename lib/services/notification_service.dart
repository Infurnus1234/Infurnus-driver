import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';
import 'notification_timing.dart';

@pragma('vm:entry-point')
Future<void> driverFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}

/// Payloads can choose an allowlisted destination, never an arbitrary route.
String? notificationDestination(Map<String, dynamic> data) {
  if (data['rideId'] is String && (data['rideId'] as String).isNotEmpty) {
    return '/driver/dashboard';
  }
  return null;
}

class DriverNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService api;
  final void Function(String route)? onOpen;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  final timing = NotificationTiming();
  bool _disposed = false, _initialized = false, _stopping = false;
  Future<void> _registration = Future<void>.value();
  String? _registeredId;
  DriverNotificationService({required this.api, this.onOpen});

  void _open(Map<String, dynamic> data) {
    if (_disposed || api.accessToken == null) return;
    timing.record(data, 'openedAt');
    final route = notificationDestination(data);
    if (route != null) onOpen?.call(route);
  }

  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      if (_disposed) return;
      FirebaseMessaging.onBackgroundMessage(
        driverFirebaseMessagingBackgroundHandler,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (details) {
          try {
            final payload = jsonDecode(details.payload ?? '{}');
            if (payload is Map<String, dynamic>) _open(payload);
          } on FormatException {
            /* Reject malformed payloads. */
          }
        },
      );
      if (_disposed) return;
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (_disposed) return;
      if (initial != null) _open(initial.data);
      final localInitial = await _plugin.getNotificationAppLaunchDetails();
      if (_disposed) return;
      if (localInitial?.didNotificationLaunchApp == true) {
        try {
          final payload = jsonDecode(
            localInitial?.notificationResponse?.payload ?? '{}',
          );
          if (payload is Map<String, dynamic>) _open(payload);
        } on FormatException {
          /* Ignore malformed payload. */
        }
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_disposed) return;
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (_disposed) return;
      if (token != null) await registerDeviceToken(token);
      if (_disposed) return;
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          if (!_disposed) unawaited(registerDeviceToken(token));
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          if (_disposed) return;
          timing.record(
            message.data,
            'foregroundReceivedAt',
            fallbackId: message.messageId,
          );
          if (notificationOfferExpired(message.data)) return;
          final id =
              message.data['notificationId']?.toString() ?? message.messageId;
          if (id != null && !_seen.add(id)) return;
          if (_seen.length > 200) _seen.remove(_seen.first);
          final notification = message.notification;
          if (notification != null) {
            unawaited(
              showNotification(
                id:
                    (id ?? notification.hashCode.toString()).hashCode &
                    0x7fffffff,
                title: notification.title ?? 'Infurnus',
                body: notification.body ?? '',
                payload: jsonEncode(message.data),
              ),
            );
          }
        }),
      );
    } catch (_) {
      // No payloads, FCM tokens or provider details are logged.
      debugPrint('Push notification setup unavailable.');
    }
  }

  Future<void> registerDeviceToken(String token) {
    _registration = _registration.then((_) => _registerToken(token));
    return _registration;
  }

  Future<void> _registerToken(String token) async {
    if (_disposed || _stopping || api.accessToken == null) return;
    final owner = api.userId;
    try {
      var device = await _storage.read(key: 'driver_device_id');
      if (_disposed || api.userId != owner) return;
      if (device == null) {
        device =
            'driver_${DateTime.now().microsecondsSinceEpoch}_${defaultTargetPlatform.name}';
        await _storage.write(key: 'driver_device_id', value: device);
      }
      if (_disposed || api.userId != owner) return;
      final result = await api.request(
        'POST',
        '/notifications/devices',
        body: {
          'fcmToken': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
          'deviceId': device,
        },
      );
      if (result is Map && api.userId == owner) {
        _registeredId = result['id']?.toString();
      }
    } catch (_) {
      debugPrint('Device registration unavailable.');
    }
  }

  Future<void> unregister() async {
    _stopping = true;
    await _registration;
    final id = _registeredId;
    if (id != null && api.accessToken != null) {
      await api.request(
        'DELETE',
        '/notifications/devices/${Uri.encodeComponent(id)}',
      );
      _registeredId = null;
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_disposed) return;
    try {
      final data = jsonDecode(payload ?? '{}');
      if (data is Map<String, dynamic>) {
        timing.record(data, 'localPresentationRequestedAt');
      }
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'infurnus_driver_channel',
            'Infurnus Driver Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {
      debugPrint('Local notification presentation unavailable.');
    }
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _seen.clear();
    timing.clear();
  }
}

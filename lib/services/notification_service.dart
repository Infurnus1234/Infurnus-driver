import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';
import 'background_ride_request.dart';
import 'notification_timing.dart';
import 'ride_request_presentation.dart';

bool _logisticsOffer(Map data) => data['logisticsTargeted'] == 'true';

int _logisticsAlertId(Map data) =>
    ('logistics-offer:${data['rideId']}').hashCode & 0x7fffffff;

const _logisticsSound = RawResourceAndroidNotificationSound(
  'ride_request_alert',
);

NotificationDetails _logisticsDetails(Map data) {
  final expires = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'infurnus_logistics_offers',
      'Logistics booking offers',
      importance: Importance.high,
      priority: Priority.high,
      sound: _logisticsSound,
      timeoutAfter: expires
          ?.difference(DateTime.now())
          .inMilliseconds
          .clamp(1, 600000),
    ),
    iOS: const DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      sound: 'infurnus_alert.wav',
    ),
  );
}

bool endsDriverOffer(Map data) =>
    const {
      'ride.accepted',
      'ride.cancelled',
      'ride.completed',
    }.contains(data['type']) &&
    data['rideId'] is String;

@pragma('vm:entry-point')
Future<void> driverFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (endsDriverOffer(message.data)) {
    await RideRequestBridge().dismissOffer(message.data['rideId'] as String);
    try {
      await FlutterLocalNotificationsPlugin().cancel(
        _logisticsAlertId(message.data),
      );
    } catch (_) {
      // This platform may not expose local notifications in the background.
    }
  }
  if (message.data['silentOfferUpdate'] == 'true') return;
  if (_logisticsOffer(message.data) && notificationOfferExpired(message.data)) {
    return;
  }
  try {
    await Firebase.initializeApp();
  } catch (_) {
    /* Native fallback does not require the UI Firebase instance. */
  }
  if (isDriverOffer(message.data)) {
    if (notificationOfferExpired(message.data)) return;
    try {
      if (await presentBackgroundOffer(message.data)) return;
    } catch (_) {
      /* A notification can still lead to authenticated review. */
    }
    final bridge = RideRequestBridge();
    if (bridge.supported) {
      final presented = await bridge.notifyOffer(
        message.data['rideId'] as String,
        message.data['expiresAt']?.toString() ?? '',
      );
      if (presented || !_logisticsOffer(message.data)) return;
    }
  }
  if (message.notification == null && message.data.isNotEmpty) {
    try {
      final title = message.data['title']?.toString() ?? 'Infurnus Driver';
      final body =
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '';
      final localPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );
      await localPlugin.initialize(initSettings);

      await localPlugin.show(
        _logisticsOffer(message.data)
            ? _logisticsAlertId(message.data)
            : (message.data['notificationId'] ?? message.hashCode.toString())
                      .hashCode &
                  0x7fffffff,
        title,
        body,
        _logisticsOffer(message.data)
            ? _logisticsDetails(message.data)
            : const NotificationDetails(
                android: AndroidNotificationDetails(
                  'infurnus_default_channel',
                  'General Notifications',
                  importance: Importance.high,
                  priority: Priority.high,
                  enableVibration: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentSound: true,
                  presentAlert: true,
                  presentBadge: true,
                ),
              ),
        payload: jsonEncode(message.data),
      );
    } catch (_) {}
  }
}

/// Payloads can choose an allowlisted destination, never an arbitrary route.
String? notificationDestination(Map<String, dynamic> data) {
  if (data['type'] == 'logistics.fleet_offer') return '/fleet/dashboard';
  if (data['rideId'] is String && (data['rideId'] as String).isNotEmpty) {
    return isDriverOffer(data)
        ? rideRequestRoute(data['rideId'] as String)
        : '/driver/active-trip';
  }
  return null;
}

class DriverNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService api;
  final void Function(String route)? onOpen;
  final void Function(Map<String, dynamic> data)? onRideUpdate;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  final timing = NotificationTiming();
  bool _disposed = false, _initialized = false, _stopping = false;
  Future<void> _registration = Future<void>.value();
  String? _registeredId;
  DriverNotificationService({
    required this.api,
    this.onOpen,
    this.onRideUpdate,
  });

  void _open(Map<String, dynamic> data) {
    if (_disposed || api.accessToken == null) return;
    unawaited(cancelAll());
    timing.record(data, 'openedAt');
    onRideUpdate?.call(data);
    final route = notificationDestination(data);
    if (route != null) onOpen?.call(route);
  }

  /// Shared by the FCM listener and deterministic SDK-boundary tests.
  bool handleForegroundData(Map<String, dynamic> data, {String? fallbackId}) {
    if (_disposed || _stopping || api.accessToken == null) return false;
    timing.record(data, 'foregroundReceivedAt', fallbackId: fallbackId);
    if (notificationOfferExpired(data)) return false;
    final id = data['notificationId']?.toString() ?? fallbackId;
    if (id != null && !_seen.add(id)) return false;
    if (endsDriverOffer(data)) {
      unawaited(RideRequestBridge().dismissOffer(data['rideId'] as String));
      unawaited(cancel(_logisticsAlertId(data)));
    }
    if (_seen.length > 200) _seen.remove(_seen.first);
    onRideUpdate?.call(data);
    return true;
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
      // The native offer bridge owns its sound and action channels.
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.deleteNotificationChannel('infurnus_driver_channel');
      await androidPlugin?.deleteNotificationChannel('infurnus_channel');
      await androidPlugin?.deleteNotificationChannel('infurnus_ride_requests');
      await androidPlugin?.deleteNotificationChannel(
        'infurnus_driver_channel_v2',
      );
      const AndroidNotificationChannel defaultChannel =
          AndroidNotificationChannel(
            'infurnus_default_channel',
            'General Notifications',
            description:
                'General alerts, document updates, and trip notifications',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );
      await androidPlugin?.createNotificationChannel(defaultChannel);
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'infurnus_logistics_offers',
          'Logistics booking offers',
          importance: Importance.high,
          sound: _logisticsSound,
        ),
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
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_disposed) return;
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
          if (!handleForegroundData(
            message.data,
            fallbackId: message.messageId,
          )) {
            return;
          }
          final id =
              message.data['notificationId']?.toString() ?? message.messageId;
          final notification = message.notification;
          if (_logisticsOffer(message.data) ||
              (notification != null && !isDriverOffer(message.data))) {
            unawaited(
              showNotification(
                id: _logisticsOffer(message.data)
                    ? _logisticsAlertId(message.data)
                    : (id ?? notification.hashCode.toString()).hashCode &
                          0x7fffffff,
                title:
                    notification?.title ??
                    message.data['title']?.toString() ??
                    'Logistics booking request',
                body:
                    notification?.body ??
                    message.data['body']?.toString() ??
                    'Open INFURNUS to review the offer.',
                payload: jsonEncode(message.data),
              ),
            );
          }
        }),
      );
    } catch (_) {
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
      if (data is Map && isDriverOffer(data) && !_logisticsOffer(data)) return;

      await _plugin.show(
        id,
        title,
        body,
        data is Map && _logisticsOffer(data)
            ? _logisticsDetails(data)
            : const NotificationDetails(
                android: AndroidNotificationDetails(
                  'infurnus_default_channel',
                  'General Notifications',
                  importance: Importance.high,
                  priority: Priority.defaultPriority,
                  playSound: true,
                  enableVibration: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentSound: true,
                  presentAlert: true,
                  presentBadge: true,
                ),
              ),
        payload: payload,
      );
    } catch (_) {
      debugPrint('Local notification presentation unavailable.');
    }
  }

  Future<void> dismissLogisticsOffer(String rideId) =>
      cancel(_logisticsAlertId({'rideId': rideId}));

  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
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

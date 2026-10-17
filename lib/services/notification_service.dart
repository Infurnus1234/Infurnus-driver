import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> driverFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling driver background message: ${message.messageId}');
}

class DriverNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService api;

  DriverNotificationService({required this.api});

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(driverFirebaseMessagingBackgroundHandler);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Driver notification tapped: ${details.payload}');
        },
      );

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Driver granted push notification permission');
        
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          await registerDeviceToken(fcmToken);
        }

        messaging.onTokenRefresh.listen((newToken) {
          registerDeviceToken(newToken);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Driver received foreground message: ${message.notification?.title}');
          final notification = message.notification;
          if (notification != null) {
            showNotification(
              id: notification.hashCode,
              title: notification.title ?? 'Infurnus Driver',
              body: notification.body ?? '',
              payload: message.data['rideId'] ?? message.data['payload'],
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Driver notification initialization error: $e');
    }
  }

  Future<void> registerDeviceToken(String fcmToken) async {
    if (api.accessToken == null) return;
    try {
      String? deviceId = await _storage.read(key: 'driver_device_id');
      if (deviceId == null) {
        deviceId = 'driver_device_${DateTime.now().millisecondsSinceEpoch}_${defaultTargetPlatform.name}';
        await _storage.write(key: 'driver_device_id', value: deviceId);
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

      await api.request('POST', '/notifications/devices', body: {
        'fcmToken': fcmToken,
        'platform': platform,
        'deviceId': deviceId,
      });
      debugPrint('Driver device token registered with backend successfully');
    } catch (e) {
      debugPrint('Failed to register driver device token: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'infurnus_driver_channel',
      'Infurnus Driver Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, platformDetails, payload: payload);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/common/notification_preferences_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/ride_request_presentation.dart';

class FakeAudioAlertBridge extends RideRequestBridge {
  bool silentAlerts = true;
  bool dndAccessGranted = false;
  int alarmVol = 5;
  int dndRequests = 0;
  bool isAlertPlaying = false;
  final List<String> stoppedAlerts = [];
  final List<Map<String, dynamic>> presentedOffers = [];

  FakeAudioAlertBridge() : super(android: true);

  @override
  Future<Map?> status() async => {
    'overlay': true,
    'notifications': true,
    'silentAlerts': silentAlerts,
    'alarmVolume': alarmVol,
    'maxAlarmVolume': 15,
    'alarmVolumeZero': alarmVol == 0,
    'dndAccess': dndAccessGranted,
    'dndActive': !dndAccessGranted,
  };

  @override
  Future<bool> getPlayAlertsInSilentMode() async => silentAlerts;

  @override
  Future<bool> setPlayAlertsInSilentMode(bool enabled) async {
    silentAlerts = enabled;
    return true;
  }

  @override
  Future<bool> requestDndAccess() async {
    dndRequests++;
    dndAccessGranted = true;
    return true;
  }

  @override
  Future<bool> present(Map<String, dynamic> ride) async {
    presentedOffers.add(ride);
    isAlertPlaying = true;
    return true;
  }

  @override
  Future<void> dismiss() async {
    isAlertPlaying = false;
    stoppedAlerts.add('dismiss');
  }

  @override
  Future<void> dismissOffer(String rideId, {bool invalidate = true}) async {
    isAlertPlaying = false;
    stoppedAlerts.add(rideId);
  }
}

class TestDriverSession extends DriverSession {
  TestDriverSession()
    : super(
        api: ApiService(
          client: MockClient((req) async {
            if (req.url.path.contains('/preferences')) {
              return http.Response(
                '{"pushNotificationsEnabled":true,"emailNotificationsEnabled":false,"smsNotificationsEnabled":true}',
                200,
              );
            }
            return http.Response('{}', 200);
          }),
        ),
      );

  @override
  bool get authenticated => true;

  String? get userId => 'test-driver-1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RideRequestBridge Silent Mode & DND MethodChannel', () {
    const channel = MethodChannel('infurnus/ride_requests');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            log.add(call);
            switch (call.method) {
              case 'status':
                return {
                  'overlay': true,
                  'notifications': true,
                  'silentAlerts': true,
                  'alarmVolume': 7,
                  'maxAlarmVolume': 15,
                  'alarmVolumeZero': false,
                  'dndAccess': true,
                  'dndActive': false,
                };
              case 'getSilentAlerts':
                return true;
              case 'setSilentAlerts':
                return true;
              case 'requestDndAccess':
                return true;
              case 'present':
                return true;
              case 'dismiss':
              case 'dismissOffer':
                return null;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'getPlayAlertsInSilentMode calls method channel and returns value',
      () async {
        final bridge = RideRequestBridge(android: true);
        final result = await bridge.getPlayAlertsInSilentMode();
        expect(result, isTrue);
        expect(log.map((c) => c.method), contains('getSilentAlerts'));
      },
    );

    test(
      'setPlayAlertsInSilentMode passes enabled flag to native channel',
      () async {
        final bridge = RideRequestBridge(android: true);
        final result = await bridge.setPlayAlertsInSilentMode(false);
        expect(result, isTrue);
        final setCall = log.firstWhere((c) => c.method == 'setSilentAlerts');
        expect(setCall.arguments, {'enabled': false});
      },
    );

    test('requestDndAccess calls native DND settings intent', () async {
      final bridge = RideRequestBridge(android: true);
      final result = await bridge.requestDndAccess();
      expect(result, isTrue);
      expect(log.map((c) => c.method), contains('requestDndAccess'));
    });

    test('status returns alarm volume and silent alert flags', () async {
      final bridge = RideRequestBridge(android: true);
      final s = await bridge.status();
      expect(s?['silentAlerts'], isTrue);
      expect(s?['alarmVolume'], 7);
      expect(s?['alarmVolumeZero'], isFalse);
      expect(s?['dndAccess'], isTrue);
    });
  });

  group('NotificationPreferencesScreen Silent Mode & DND UI', () {
    late TestDriverSession session;
    late FakeAudioAlertBridge bridge;

    setUp(() {
      session = TestDriverSession();
      bridge = FakeAudioAlertBridge();
    });

    tearDown(() {
      session.dispose();
    });

    testWidgets('renders silent mode toggle defaulting to ON', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: NotificationPreferencesScreen(bridge: bridge),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play ride alerts even in silent mode'), findsOneWidget);
      final switchFinder = find.widgetWithText(
        SwitchListTile,
        'Play ride alerts even in silent mode',
      );
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);

      // Toggle OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(bridge.silentAlerts, isFalse);
      final updatedWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(updatedWidget.value, isFalse);
    });

    testWidgets('shows warning when alarm volume is zero', (tester) async {
      bridge.alarmVol = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: NotificationPreferencesScreen(bridge: bridge),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Alarm volume is currently set to zero'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows DND prompt and opens settings when access not granted', (
      tester,
    ) async {
      bridge.dndAccessGranted = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: NotificationPreferencesScreen(bridge: bridge),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Do Not Disturb access (Optional)'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(bridge.dndRequests, 1);
      expect(bridge.dndAccessGranted, isTrue);
    });
  });

  group('Audio Alert Start & Stop Lifecycle', () {
    test(
      'sound starts on present and stops on dismiss / dismissOffer',
      () async {
        final fakeBridge = FakeAudioAlertBridge();

        expect(fakeBridge.isAlertPlaying, isFalse);

        // 1. Offer arrives -> present starts alert sound
        final offer = {
          'id': 'ride-offer-123',
          'key': 'ride-offer-123:2026-11-18T12:00:00Z',
          'dispatchExpiresAt': DateTime.now()
              .add(const Duration(seconds: 30))
              .toIso8601String(),
          'pickupAddress': 'Station',
          'destinationAddress': 'Market',
        };
        await fakeBridge.present(offer);

        expect(fakeBridge.isAlertPlaying, isTrue);
        expect(fakeBridge.presentedOffers, hasLength(1));

        // 2. Reject / dismissOffer stops alert sound
        await fakeBridge.dismissOffer('ride-offer-123');
        expect(fakeBridge.isAlertPlaying, isFalse);
        expect(fakeBridge.stoppedAlerts, contains('ride-offer-123'));

        // 3. New offer arrives -> present starts alert sound
        await fakeBridge.present(offer);
        expect(fakeBridge.isAlertPlaying, isTrue);

        // 4. Accept / dismiss stops alert sound
        await fakeBridge.dismiss();
        expect(fakeBridge.isAlertPlaying, isFalse);
        expect(fakeBridge.stoppedAlerts, contains('dismiss'));
      },
    );
  });
}

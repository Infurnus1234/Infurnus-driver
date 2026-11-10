import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/driver_request_host.dart';
import 'package:infurnus_driver/main.dart';
import 'package:infurnus_driver/router/app_router.dart';
import 'package:infurnus_driver/services/ride_request_presentation.dart';

class RequestSession extends DriverSession {
  RequestSession()
    : super(
        api: ApiService(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
  final accepted = Completer<void>();
  int accepts = 0, declines = 0;
  @override
  Future<bool> decline(String id) async {
    declines++;
    rides = [];
    notifyListeners();
    return true;
  }

  @override
  bool get authenticated => true;
  @override
  Future<bool> refresh({bool automatic = false}) async => true;
  @override
  Future<bool> accept(String id) async {
    accepts++;
    await accepted.future;
    currentTrip = {'id': id, 'status': 'driver_assigned'};
    rides = [];
    notifyListeners();
    return true;
  }
}

class BackgroundBridge extends RideRequestBridge {
  final offers = <Map<String, dynamic>>[];
  final dismissals = <String>[];
  Map<String, dynamic>? action;
  @override
  Future<Map<String, dynamic>?> takeAction() async {
    final pending = action;
    action = null;
    return pending;
  }

  @override
  Future<bool> present(Map<String, dynamic> ride) async {
    offers.add(ride);
    return true;
  }

  @override
  Future<void> dismissOffer(String rideId, {bool invalidate = true}) async {
    dismissals.add(rideId);
  }
}

void main() {
  testWidgets('drawer opens requests and the separate alert settings sheet', (
    tester,
  ) async {
    final session = RequestSession()
      ..restoring = false
      ..roleEnrolment = {'dashboardAccessible': true};
    final router = createAppRouter();
    addTearDown(session.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/driver/dashboard');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ride requests'));
    await tester.pumpAndSettle();
    expect(find.text('Ride requests'), findsOneWidget);
    expect(find.text('No current offers.'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ride request alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Display over other apps'), findsOneWidget);
    expect(find.text('Allow request notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    router.go(rideRequestRoute('expired-offer'));
    await tester.pumpAndSettle();
    expect(find.text('This offer is no longer available.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Today’s Ride Summary'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'paused socket receipt reaches native bridge without rendering a frame',
    (tester) async {
      final session = RequestSession(), bridge = BackgroundBridge();
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: DriverRequestHost(
              bridge: bridge,
              navigate: (_) {},
              child: const Scaffold(),
            ),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      session.rides = [
        {
          'id': 'background',
          'dispatchExpiresAt': DateTime.now()
              .add(const Duration(minutes: 1))
              .toIso8601String(),
        },
      ];
      session.notifyListeners();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(bridge.offers.single['id'], 'background');
      expect(bridge.offers.single['_presentInApp'], false);
      session.notifyListeners();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(bridge.offers, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('native Reject is consumed once and returns to the dashboard', (
    tester,
  ) async {
    final session = RequestSession(),
        bridge = BackgroundBridge()
          ..action = {
            'rideId': 'reject-me',
            'action': 'reject',
            'deadline': DateTime.now()
                .add(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
          };
    final routes = <String>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: MaterialApp(
          home: DriverRequestHost(
            bridge: bridge,
            navigate: routes.add,
            child: const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    session.notifyListeners();
    await tester.pump();
    expect(session.declines, 1);
    expect(routes, ['/driver/dashboard']);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'duplicate taps and session notifications produce one acceptance and one navigation',
    (tester) async {
      final bridge = BackgroundBridge();
      final session = RequestSession()
        ..rides = [
          {
            'id': 'live',
            'dispatchExpiresAt': DateTime.now()
                .add(const Duration(minutes: 1))
                .toIso8601String(),
            'pickupAddress': 'Real server pickup',
          },
        ];
      final routes = <String>[];
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            home: DriverRequestHost(
              bridge: bridge,
              navigate: routes.add,
              child: const Scaffold(body: Text('Dashboard')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('New Ride Request'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pump();
      session.notifyListeners();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(session.accepts, 1);
      expect(bridge.dismissals, ['live']);
      expect(bridge.offers, hasLength(1));
      session.accepted.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(routes, ['/driver/active-trip']);
      expect(find.text('New Ride Request'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'real application builder supplies the Overlay required by request controls',
    (tester) async {
      final session = RequestSession()
        ..roleEnrolment = {'role': 'driver', 'dashboardAccessible': true}
        ..onboardingLoaded = true
        ..account = {'firstName': 'Local'}
        ..rides = [
          {
            'id': 'root-offer',
            'dispatchExpiresAt': DateTime.now()
                .add(const Duration(minutes: 1))
                .toIso8601String(),
            'pickupAddress': 'Local pickup',
          },
        ];
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const InfurnusApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('New Ride Request'), findsOneWidget);
      expect(find.byTooltip('Close ride request'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close ride request'));
      await tester.pump();
      await tester.pump();
      expect(find.text('New Ride Request'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      appRouter.go('/login');
    },
  );
  testWidgets(
    'OTP remains mounted while authenticated account state is still loading',
    (tester) async {
      final session = RequestSession()..busy = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const InfurnusApp(),
        ),
      );
      appRouter.go('/otp');
      await tester.pump();
      await tester.pump();
      expect(find.text('Verify your account'), findsOneWidget);
      expect(appRouter.routeInformationProvider.value.uri.path, '/otp');
      session.roleEnrolment = {'role': 'driver', 'dashboardAccessible': true};
      session.onboardingLoaded = true;
      session.account = {'firstName': 'Local'};
      session.busy = false;
      session.notifyListeners();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/driver/dashboard',
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      appRouter.go('/login');
    },
  );
}

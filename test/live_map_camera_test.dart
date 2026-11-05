import 'package:infurnus_driver/widgets/vehicle_motion.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/trip_map.dart';

import 'recording_maps.dart';

class MapSession extends DriverSession {
  MapSession(ApiService superApi) : super(api: superApi);
  @override
  Future<bool> locate() async => true;
  void move(Position fix) {
    position = fix;
    notifyListeners();
  }

  void finish() {
    currentTrip = null;
    notifyListeners();
  }
}

Position fix(DateTime time, double latitude, double heading) => Position(
  latitude: latitude,
  longitude: 85.1376,
  timestamp: time,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 1,
  speed: 5,
  speedAccuracy: 1,
);
void main() {
  testWidgets(
    'booking, pickup, PIN and completion preserve the native map and correct markers',
    (tester) async {
      await tester.runAsync(navigationArrow);
      final previous = GoogleMapsFlutterPlatform.instance;
      final maps = RecordingMaps();
      GoogleMapsFlutterPlatform.instance = maps;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('infurnus/maps'),
        (_) async => true,
      );
      final calls = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          calls.add(r.url.path);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'routeVersion': 1,
                'route': {
                  'distanceMeters': 1000,
                  'durationSeconds': 120,
                  'encodedPolyline': '???o}@',
                },
              },
            }),
            200,
          );
        }),
      );
      final session = MapSession(api)
        ..position = fix(DateTime.now(), 25.5941, 0);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TripMap(compact: true)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(GoogleMap), findsOneWidget);
      for (final status in [
        'driver_assigned',
        'driver_arriving',
        'driver_arrived',
        'in_progress',
      ]) {
        session.currentTrip = {
          'id': 'lifecycle-ride',
          'status': status,
          'pinVerified': status == 'in_progress',
          'pickup': {'latitude': 25.6, 'longitude': 85.14},
          'destination': {'latitude': 25.61, 'longitude': 85.15},
        };
        session.move(fix(DateTime.now(), 25.5941, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(
          map.markers.any((m) => m.markerId.value == 'pickup'),
          status != 'in_progress',
        );
        expect(map.markers.any((m) => m.markerId.value == 'driver'), isTrue);
        expect(
          map.markers.any((m) => m.markerId.value == 'destination'),
          isTrue,
        );
        expect(map.polylines, isNotEmpty);
        expect(maps.created.length, 1);
      }
      session.finish();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines,
        isEmpty,
      );
      expect(maps.created.length, 1);
      expect(
        calls.every((p) => p == '/rides/driver/rides/lifecycle-ride/map'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'structured route throttling keeps map markers and recovers on a successful refresh',
    (tester) async {
      await tester.runAsync(navigationArrow);
      final previous = GoogleMapsFlutterPlatform.instance;
      final maps = RecordingMaps();
      GoogleMapsFlutterPlatform.instance = maps;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('infurnus/maps'),
        (_) async => true,
      );
      var attempts = 0;
      final session =
          MapSession(
              ApiService(
                client: MockClient((_) async {
                  attempts++;
                  return attempts == 1
                      ? http.Response(
                          jsonEncode({
                            'success': false,
                            'error': {
                              'code': 'MAP_RATE_LIMITED',
                              'message': 'Wait before refreshing the map.',
                            },
                          }),
                          429,
                        )
                      : http.Response(
                          jsonEncode({
                            'success': true,
                            'data': {
                              'routeVersion': 1,
                              'route': {
                                'distanceMeters': 1000,
                                'durationSeconds': 120,
                                'encodedPolyline': '???o}@',
                              },
                            },
                          }),
                          200,
                        );
                }),
              ),
            )
            ..position = fix(DateTime.now(), 25.5941, 0)
            ..currentTrip = {
              'id': 'retry-ride',
              'status': 'driver_assigned',
              'pickup': {'latitude': 25.6, 'longitude': 85.14},
            };
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: TripMap())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Wait before refreshing the map.'), findsOneWidget);
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.length,
        2,
      );
      await tester.ensureVisible(find.text('Refresh route'));
      await tester.tap(find.text('Refresh route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Wait before refreshing the map.'), findsNothing);
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines,
        isNotEmpty,
      );
      expect(maps.created.length, 1);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('early GPS is replayed after delayed Driver map initialization', (
    tester,
  ) async {
    await tester.runAsync(navigationArrow);
    final previous = GoogleMapsFlutterPlatform.instance;
    final maps = RecordingMaps(deferCreation: true);
    GoogleMapsFlutterPlatform.instance = maps;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('infurnus/maps'),
      (_) async => true,
    );
    final api = ApiService(
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final session = MapSession(api);
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: TripMap())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    session.move(fix(DateTime.now(), 25.5941, 0));
    await tester.pump();
    await tester.pump();
    maps.completeCreation();
    await tester.pump();
    await tester.pump();
    expect(maps.cameraCalls, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'driver map animates arrow, follows until pan, recenters, and retains route between GPS samples',
    (tester) async {
      await tester.runAsync(navigationArrow);
      final previous = GoogleMapsFlutterPlatform.instance;
      final maps = RecordingMaps();
      GoogleMapsFlutterPlatform.instance = maps;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = previous);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('infurnus/maps'),
        (_) async => true,
      );
      var routeCalls = 0;
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/rides/driver/rides/ride/map');
          expect(request.url.queryParameters['includeRoute'], 'true');
          routeCalls++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'routeVersion': 1,
                'route': {
                  'distanceMeters': 1000,
                  'durationSeconds': 120,
                  'encodedPolyline': '???o}@',
                },
              },
            }),
            200,
          );
        }),
      );
      final session = MapSession(api);
      final start = DateTime.now();
      session.currentTrip = {
        'id': 'ride',
        'status': 'driver_arriving',
        'pickup': {'latitude': 25.6, 'longitude': 85.14},
      };
      session.position = fix(start, 25.5941, 0);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: TripMap())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(routeCalls, 1);
      final before = maps.cameraCalls;
      session.move(fix(start.add(const Duration(seconds: 1)), 25.59415, 90));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final marker = tester
          .widget<GoogleMap>(find.byType(GoogleMap))
          .markers
          .singleWhere((m) => m.markerId.value == 'driver');
      expect(marker.position.latitude, greaterThan(25.5941));
      expect(marker.position.latitude, lessThan(25.59415));
      expect(marker.rotation, greaterThan(0));
      expect(marker.flat, isTrue);
      expect(maps.cameraCalls, greaterThan(before));
      await tester.tap(find.byKey(const Key('recording-map')));
      final afterPan = maps.cameraCalls;
      session.move(fix(start.add(const Duration(seconds: 2)), 25.5942, 90));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(maps.cameraCalls, afterPan);
      expect(routeCalls, 1);
      await tester.ensureVisible(find.text('Recenter / follow'));
      await tester.tap(find.text('Recenter / follow'));
      await tester.pump();
      expect(maps.cameraCalls, greaterThan(afterPan));
      session.finish();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).polylines,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

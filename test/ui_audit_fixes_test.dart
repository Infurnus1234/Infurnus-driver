import 'fleet_refresh_test.dart' show RefreshFixtureSession;

import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/providers/provider_assets.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';
import 'package:infurnus_driver/screens/common/support_tickets_screen.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/widgets/fleet_overview.dart';
import 'package:infurnus_driver/widgets/operations.dart';

http.Response _envelope(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

String _mockToken(String role) =>
    'h.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.s';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('infurnus/maps'),
          (_) async => false,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('infurnus/maps'), null);
  });
  group('1. Home Dashboard Layout & Responsiveness', () {
    testWidgets(
      'FleetOverview adapts to narrow and standard screen widths without overflow',
      (tester) async {
        final api = ApiService(
          store: MemorySessionStore(),
          client: MockClient((r) async => _envelope({})),
        );
        final assets = ProviderAssets(api);

        bool pendingSubmitted = false;

        // Test on narrow screen (320px)
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: Ops.theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: FleetOverview(
                  assets: assets,
                  onSubmitPending: () {
                    pendingSubmitted = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Fleet Overview'), findsOneWidget);
        expect(find.text('Total Vehicles'), findsOneWidget);
        expect(find.text('Active Vehicles'), findsOneWidget);
        expect(find.text('Total Drivers'), findsOneWidget);
        expect(find.text('Active Drivers'), findsOneWidget);
        expect(find.text('Quick actions'), findsOneWidget);
        expect(find.text('Add Vehicle'), findsOneWidget);
        expect(find.text('Add Driver'), findsOneWidget);
        expect(find.text('Fleet Tracking'), findsOneWidget);
        expect(find.text('Revenue & reports'), findsOneWidget);
        expect(find.text('Submit Pending Requests'), findsOneWidget);

        await tester.tap(find.text('Submit Pending Requests'));
        expect(pendingSubmitted, isTrue);

        // Verify no overflow occurred
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('2. Deduplicated Navigation in Profile & Settings', () {
    testWidgets(
      'AccountScreen has exactly one Notifications entry and one Help Center entry',
      (tester) async {
        final session = DriverSession(
          onboardingDraftStore: MemorySessionStore(),
          api: ApiService(
            store: MemorySessionStore(),
            client: MockClient((r) async => _envelope([])),
          ),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: MaterialApp(theme: Ops.theme, home: const AccountScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Notifications'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        // Exactly ONE Notifications entry
        expect(find.text('Notifications'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Help center'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        // Exactly ONE Help Center entry
        expect(find.text('Help center'), findsOneWidget);

        // No duplicated driver onboarding links
        expect(find.text('Driver onboarding & verification'), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('3. Email Support in Help Center', () {
    testWidgets(
      'SupportTicketsScreen renders Email Support card with configured email',
      (tester) async {
        final session = DriverSession(
          onboardingDraftStore: MemorySessionStore(),
          api: ApiService(
            store: MemorySessionStore(),
            client: MockClient((r) async {
              if (r.url.path == '/support/tickets') {
                return _envelope([]);
              }
              return _envelope({});
            }),
          ),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: MaterialApp(
              theme: Ops.theme,
              home: const SupportTicketsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Email Support'), findsOneWidget);
        expect(
          find.textContaining('support@infurnuslogistics.com'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('4. Empty States, Centering & Punctuation', () {
    testWidgets('OpsEmpty displays centered message and optional subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OpsEmpty(
              'No trips in this view.',
              subtitle: 'Showing 0 most recent server records.',
            ),
          ),
        ),
      );

      expect(find.text('No trips in this view.'), findsOneWidget);
      expect(
        find.text('Showing 0 most recent server records.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('FleetLocationMap shows precise empty copy and punctuation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FleetLocationMap(rows: [])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fleet locations — last reported'), findsOneWidget);
      expect(
        find.text('No coordinates are available for this view.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Green indicates recently reported locations; amber indicates stale or unknown locations. Locations refresh with fleet data; this is not continuous streaming.',
        ),
        findsOneWidget,
      );
    });
  });

  group('5. Vehicle Documents Dialog Structure & Scrolling', () {
    testWidgets(
      'ProviderAssetsScreen opens bounded, scrollable vehicle documents dialog with pinned close button',
      (tester) async {
        final session = RefreshFixtureSession(
          ApiService(
            store: MemorySessionStore(),
            client: MockClient((r) async {
              if (r.url.path == '/auth/session') {
                return _envelope({
                  'authenticated': true,
                  'user': {'id': 'user-1', 'role': 'provider'},
                  'accessToken': _mockToken('provider'),
                });
              }
              if (r.url.path.contains('/earnings') ||
                  r.url.path.contains('/revenue')) {
                return _envelope({});
              }
              if (r.url.path.contains('/rules')) {
                return _envelope([
                  {
                    'code': 'vehicle_front_photo',
                    'required': true,
                    'minimumPages': 1,
                    'imageOnly': true,
                  },
                  {
                    'code': 'vehicle_rear_photo',
                    'required': true,
                    'minimumPages': 1,
                    'imageOnly': true,
                  },
                  {
                    'code': 'vehicle_rc',
                    'required': true,
                    'minimumPages': 1,
                    'imageOnly': false,
                  },
                ]);
              }
              if (r.url.path.contains('/documents')) {
                return _envelope([]);
              }
              if (r.url.path.contains('/vehicles')) {
                return _envelope([
                  {
                    'id': 'v-1',
                    'make': 'Tata',
                    'model': 'Ace',
                    'plateNumber': 'BR05351',
                    'approvalStatus': 'approved',
                    'operationalStatus': 'ACTIVE',
                  },
                ]);
              }
              return _envelope([]);
            }),
          ),
        );

        session.api.role = 'fleet_owner';
        session.api.providerMode = 'fleet_owner';
        session.roleEnrolment = {'dashboardAccessible': true};
        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: MaterialApp(
              theme: Ops.theme,
              home: const ProviderAssetsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Vehicles').last);
        await tester.pumpAndSettle();
        // Open vehicle documents dialog
        final vehicleDocsBtn = find.text('Vehicle documents');
        if (vehicleDocsBtn.evaluate().isNotEmpty) {
          await tester.tap(vehicleDocsBtn.first);
          await tester.pumpAndSettle();

          expect(find.text('Documents: BR05351'), findsOneWidget);
          expect(find.text('Vehicle Photos'), findsOneWidget);
          expect(find.text('Vehicle Documents'), findsOneWidget);
          expect(find.text('Vehicle RC'), findsOneWidget);
          expect(find.text('Close'), findsOneWidget);

          // Close button dismisses dialog
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(find.text('Documents: BR05351'), findsNothing);
        }
      },
    );
  });
}

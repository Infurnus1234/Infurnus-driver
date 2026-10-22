import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';
import 'package:infurnus_driver/screens/common/operations_screens.dart';
import 'package:infurnus_driver/screens/common/notification_inbox_screen.dart';
import 'package:infurnus_driver/screens/common/notification_preferences_screen.dart';
import 'package:infurnus_driver/screens/common/bank_account_screen.dart';
import 'package:infurnus_driver/screens/common/support_tickets_screen.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/screens/fleet/fleet_reports_screen.dart';
import 'package:infurnus_driver/widgets/operations.dart';

class VisualSession extends DriverSession {
  VisualSession(ApiService api) : super(api: api) {
    onboardingLoaded = true;
    account = {'firstName': 'Fixture', 'lastName': 'Driver'};
    profile = {
      'id': 'fixture-driver',
      'licenseNumber': 'FIXTURE',
      'licenseExpiry': '2099-12-31',
      'verificationStatus': 'approved',
      'availabilityStatus': 'offline',
    };
    assignedVehicle = {
      'id': 'vehicle',
      'plateNumber': 'TEST 001',
      'category': 'VAN',
      'make': 'Fixture',
      'model': 'Vehicle',
      'verificationStatus': 'approved',
      'isActive': true,
    };
    history = {
      'totalTrips': 8,
      'totalEarnings': 1280,
      'rides': [
        {
          'id': 'fixture-trip',
          'status': 'completed',
          'pickupAddress': 'Boring Road',
          'destinationAddress': 'Patna Junction',
          'createdAt': '2026-10-20 10:32',
          'finalFare': 286,
        },
        {
          'id': 'fixture-cancelled',
          'status': 'cancelled',
          'pickupAddress': 'Kankarbagh',
          'destinationAddress': 'Fraser Road',
          'createdAt': '2026-10-19 08:45',
          'finalFare': 0,
        },
      ],
    };
  }
  @override
  bool get authenticated => true;
}

void main() {
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter') as Map;
    final root = Directory.fromUri(
      config.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final fonts = root.uri.resolve('bin/cache/artifacts/material_fonts/');
    final text = FontLoader('Roboto')
      ..addFont(
        File.fromUri(fonts.resolve('roboto-regular.ttf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File.fromUri(fonts.resolve('materialicons-regular.otf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await text.load();
    await icons.load();
  });

  const cases = [
    'driver-offline',
    'driver-online',
    'ride-offer',
    'pickup',
    'active-trip',
    'pin-verification',
    'pin-verification-large',
    'trips',
    'earnings',
    'wallet',
    'profile',
    'notifications',
    'notification-settings',
    'bank',
    'support',
    'fleet-home',
    'fleet-vehicles',
    'fleet-drivers',
    'fleet-tracking',
    'fleet-more',
    'add-vehicle',
    'edit-vehicle',
    'fleet-reports',
    'mode-switch',
    'confirmation',
    'driver-offline-large',
    'fleet-home-large',
    'fleet-drivers-large',
  ];
  for (final caseId in cases) {
    final large = caseId.endsWith('-large');
    final name = caseId.replaceFirst('-large', '');
    testWidgets('reference UI $caseId', (tester) async {
      tester.view.physicalSize = large
          ? const Size(320, 780)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('infurnus/maps'),
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('infurnus/maps'),
          null,
        ),
      );
      final unknown = <String>[];
      final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final days = List.generate(
        7,
        (i) => {
          'day': DateTime.now()
              .toUtc()
              .subtract(Duration(days: 6 - i))
              .toIso8601String(),
          'grossPaise': (i + 1) * 20000,
          'commissionPaise': (i + 1) * 2000,
          'netPaise': (i + 1) * 18000,
        },
      );
      final periods = [
        for (final period in ['daily', 'weekly', 'monthly'])
          {
            'period': period,
            'grossPaise': 142000,
            'netPaise': 124600,
            'commissionPaise': 17400,
            'adjustmentPaise': 0,
          },
      ];
      final api =
          ApiService(
              client: MockClient((r) async {
                dynamic data;
                switch (r.url.path) {
                  case '/partners/me':
                    data = {
                      'id': 'partner',
                      'businessName': 'Fixture Fleet',
                      'approvalStatus': 'APPROVED',
                    };
                  case '/partners/partner/documents':
                    data = [];
                  case '/provider/managed-drivers':
                    data = [];
                  case '/provider/vehicle-catalog':
                    data = {
                      'sectors': [
                        'passenger',
                        'logistics',
                        'premium',
                        'service',
                        'rental',
                      ],
                      'types': [
                        {
                          'code': 'sedan',
                          'name': 'Sedan',
                          'sector': 'passenger',
                          'active': true,
                        },
                      ],
                    };
                  case '/provider/approvals':
                    data = [];
                  case '/provider/onboarding':
                    return http.Response(
                      jsonEncode({
                        'success': true,
                        'data': {
                          'dashboardAccessible': false,
                          'deferred_codes': [],
                        },
                      }),
                      200,
                    );
                  case '/provider/document-requirements':
                    data = [];
                  case '/fleet/vehicles':
                    data = [
                      {
                        'id': 'vehicle',
                        'make': 'Maruti Suzuki',
                        'model': 'Dzire',
                        'plateNumber': 'TEST 001',
                        'category': 'SEDAN',
                        'approvalStatus': 'APPROVED',
                        'verificationStatus': 'approved',
                        'operationalStatus': 'ACTIVE',
                      },
                      {
                        'id': 'vehicle2',
                        'make': 'Tata',
                        'model': 'Ace',
                        'plateNumber': 'TEST 002',
                        'category': 'VAN',
                        'approvalStatus': 'APPROVED',
                        'verificationStatus': 'approved',
                        'operationalStatus': 'INACTIVE',
                      },
                    ];
                  case '/fleet/drivers':
                    data = [
                      {
                        'id': 'driver1',
                        'driverProfileId': 'driver1',
                        'name': 'Fixture Driver',
                        'status': 'ACTIVE',
                        'availabilityStatus': 'available',
                      },
                      {
                        'id': 'driver2',
                        'driverProfileId': 'driver2',
                        'name': 'Fixture Partner',
                        'status': 'INACTIVE',
                        'availabilityStatus': 'unavailable',
                      },
                    ];
                  case '/provider/tracking':
                    data = [];
                  case '/provider/earnings':
                    data = {'periods': periods, 'days': days};
                  case '/fleet/earnings':
                    data = {
                      'thisMonthRevenue': 124600,
                      'todayRevenue': 1280,
                      'thisWeekRevenue': 8000,
                      'platformCommission': 1400,
                      'netPayout': 11200,
                      'totalTrips': 420,
                    };
                  case '/fleet/trips':
                    data = [
                      {
                        'id': 'trip',
                        'vehiclePlate': 'TEST 001',
                        'driverName': 'Fixture Driver',
                        'status': 'completed',
                        'pickupAddress': 'Boring Road',
                        'destinationAddress': 'Patna Junction',
                        'createdAt': day,
                        'finalFare': 286,
                      },
                    ];
                  case '/provider/wallet':
                    data = {
                      'balancePaise': 124600,
                      'entries': [
                        {
                          'entry_type': 'Ride settlement',
                          'created_at': day,
                          'reference': 'FIXTURE-001',
                          'amount_paise': 28600,
                        },
                        {
                          'entry_type': 'Payout requested',
                          'created_at': day,
                          'reference': 'FIXTURE-002',
                          'amount_paise': -20000,
                        },
                      ],
                    };
                  case '/notifications/inbox':
                    data = {
                      'unreadCount': 1,
                      'items': [
                        {
                          'id': 'fixture-notification',
                          'title': 'Trip status updated',
                          'body': 'Open INFURNUS to view your trip.',
                          'createdAt': day,
                          'readAt': null,
                        },
                      ],
                    };
                  case '/users/fixture-user/preferences':
                    data = {
                      'pushNotificationsEnabled': true,
                      'emailNotificationsEnabled': false,
                      'smsNotificationsEnabled': false,
                    };
                  case '/provider/bank-account':
                    data = {
                      'bankName': 'Fixture Bank',
                      'accountNumberLast4': '1234',
                      'isVerified': false,
                    };
                  case '/support/tickets':
                    data = [
                      {
                        'id': 'fixture-ticket',
                        'subject': 'Document review question',
                        'message': 'Please help with my document review.',
                        'ticketNumber': 'FIXTURE-01',
                        'status': 'OPEN',
                      },
                    ];
                  default:
                    unknown.add(r.url.path);
                    data = {};
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': data}),
                  200,
                );
              }),
            )
            ..userId = 'fixture-user'
            ..accessToken = 'fixture-token'
            ..role = 'driver_fleet_owner';
      final session = VisualSession(api);
      addTearDown(session.dispose);
      Widget screen = const OperationsDashboard();
      if (name.startsWith('fleet-') ||
          name == 'add-vehicle' ||
          name == 'edit-vehicle') {
        api.providerMode = 'fleet_owner';
      }
      if (name == 'driver-online') {
        session.profile!['availabilityStatus'] = 'available';
      }
      if (name == 'ride-offer') {
        session.rides = [
          {
            'id': 'fixture-offer',
            'pickupAddress': 'Boring Road, Patna',
            'destinationAddress': 'Patna Junction',
            'vehicleCategory': 'SEDAN',
            'fareEstimate': 286,
          },
        ];
      }
      if (name == 'pickup' ||
          name == 'active-trip' ||
          name == 'pin-verification') {
        session.currentTrip = {
          'id': 'fixture-trip',
          'status': name == 'pickup'
              ? 'driver_arriving'
              : name == 'pin-verification'
              ? 'driver_arrived'
              : 'in_progress',
          'pinVerified': name == 'active-trip',
          'pickupAddress': 'Boring Road, Patna',
          'destinationAddress': 'Patna Junction',
          'vehicleCategory': 'SEDAN',
          'fareEstimate': 286,
        };
      }
      switch (name) {
        case 'trips':
          screen = const TripsScreen();
        case 'earnings':
          screen = const LedgerScreen();
        case 'wallet':
          screen = const LedgerScreen(wallet: true);
        case 'profile':
          screen = const AccountScreen();
        case 'notifications':
          screen = const ServerNotificationInbox();
        case 'notification-settings':
          screen = const NotificationPreferencesScreen();
        case 'bank':
          screen = const BankAccountScreen();
        case 'support':
          screen = const SupportTicketsScreen();
        case 'fleet-home' ||
            'fleet-vehicles' ||
            'fleet-drivers' ||
            'fleet-tracking' ||
            'fleet-more' ||
            'add-vehicle' ||
            'edit-vehicle':
          screen = const ProviderAssetsScreen();
        case 'fleet-reports':
          screen = const FleetReportsScreen();
        case 'confirmation':
          screen = Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => confirmOperation(
                    context,
                    'Complete this trip?',
                    'Confirm that the passenger or shipment has reached the destination.',
                  ),
                  child: const Text('Review completion'),
                ),
              ),
            ),
          );
      }
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
              child: child!,
            ),
            theme: Ops.theme,
            home: RepaintBoundary(key: const ValueKey('screen'), child: screen),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if ([
        'fleet-vehicles',
        'fleet-drivers',
        'fleet-tracking',
        'fleet-more',
        'add-vehicle',
        'edit-vehicle',
      ].contains(name)) {
        final label = name == 'fleet-drivers'
            ? 'Drivers'
            : name == 'fleet-tracking'
            ? 'Tracking'
            : name == 'fleet-more'
            ? 'More'
            : 'Vehicles';
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }
      if (name == 'add-vehicle') {
        await tester.tap(find.text('Add vehicle'));
        await tester.pumpAndSettle();
      }
      if (name == 'edit-vehicle') {
        await tester.tap(find.text('Maruti Suzuki Dzire'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Edit vehicle').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit vehicle').first);
        await tester.pumpAndSettle();
      }
      if (name == 'mode-switch') {
        await tester.tap(find.text('Driver Mode'));
        await tester.pumpAndSettle();
      }
      if (name == 'pin-verification') {
        await tester.tap(find.text('Verify PIN & start trip'));
        await tester.pumpAndSettle();
      }
      if (name == 'confirmation') {
        await tester.tap(find.text('Review completion'));
        await tester.pumpAndSettle();
      }
      if (['ride-offer', 'pickup', 'active-trip'].contains(name)) {
        final target = name == 'ride-offer'
            ? find.text('New Ride Request')
            : find.text(
                name == 'active-trip' ? 'On Ride' : 'Navigate to Pickup',
              );
        await tester.scrollUntilVisible(
          target,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      expect(
        unknown,
        isEmpty,
        reason: 'Every rendered fixture must use a known existing API.',
      );
      expect(tester.takeException(), isNull);
      // Date-aware finance screens are captured on request; their ordinary
      // regression checks validate layout/API/navigation rather than today's pixels.
      if (const bool.fromEnvironment('CAPTURE_REFERENCE_UI')) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/reference-ui/$caseId.png'),
        );
      }
      if (name == 'fleet-vehicles') {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
        await tester.pumpAndSettle();
        expect(find.text('Tata Ace'), findsNothing);
        expect(find.text('Maruti Suzuki Dzire'), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Tata');
        await tester.pumpAndSettle();
        expect(find.text('Tata Ace'), findsOneWidget);
        expect(find.text('Maruti Suzuki Dzire'), findsNothing);
      }
      if (name == 'add-vehicle') {
        expect(find.text('Vehicle category and type'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('passenger').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sedan').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsNWidgets(3));
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}

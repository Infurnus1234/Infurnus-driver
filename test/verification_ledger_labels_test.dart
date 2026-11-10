import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/models/provider_status.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/widgets/reference_components.dart';

class _TestSession extends DriverSession {
  _TestSession({required super.api, required super.onboardingDraftStore});
  @override
  bool get authenticated => true;
}

void main() {
  group('DA-12 Central Label Mappers', () {
    test(
      'verificationRequestLabel maps technical enums to user-facing labels',
      () {
        expect(
          verificationRequestLabel('fleet_verification'),
          'Fleet Verification',
        );
        expect(
          verificationRequestLabel('vehicle_verification'),
          'Vehicle Verification',
        );
        expect(
          verificationRequestLabel('driver_verification'),
          'Driver Verification',
        );
        expect(
          verificationRequestLabel('fleet_submission'),
          'Fleet Submission',
        );
        expect(
          verificationRequestLabel('partner_verification'),
          'Partner Verification',
        );
        expect(
          verificationRequestLabel('document_verification'),
          'Document Verification',
        );
        expect(verificationRequestLabel('custom_check'), 'Custom Check');
        expect(verificationRequestLabel(null), 'Verification Request');
      },
    );

    test('ledgerPeriodLabel capitalises and formats periods correctly', () {
      expect(ledgerPeriodLabel('daily'), 'Daily');
      expect(ledgerPeriodLabel('weekly'), 'Weekly');
      expect(ledgerPeriodLabel('monthly'), 'Monthly');
      expect(ledgerPeriodLabel('yearly'), 'Yearly');
      expect(ledgerPeriodLabel(null), 'Period');
    });
  });

  group('DA-12 Verification Requests and Settlement Ledger Widget UI', () {
    testWidgets(
      'renders verification request cards and settlement ledger cards with formatted labels and currency',
      (tester) async {
        final session = _TestSession(
          onboardingDraftStore: MemorySessionStore(),
          api: ApiService(
            store: MemorySessionStore(),
            client: MockClient((r) async {
              final path = r.url.path;
              if (path == '/partners/me') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {
                      'id': 'test-fleet',
                      'businessName': 'TEST_SAMPLE',
                      'approvalStatus': 'approved',
                    },
                  }),
                  200,
                );
              }
              if (path == '/provider/approvals') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': [
                      {
                        'id': 'app-1',
                        'request_type': 'fleet_verification',
                        'status': 'APPROVED',
                      },
                      {
                        'id': 'app-2',
                        'request_type': 'vehicle_verification',
                        'status': 'REJECTED',
                        'rejection_reason': 'RC image is blurred',
                      },
                    ],
                  }),
                  200,
                );
              }
              if (path == '/provider/earnings' || path == '/fleet/earnings') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {
                      'periods': [
                        {
                          'period': 'daily',
                          'grossPaise': 150000,
                          'commissionPaise': 25000,
                          'netPaise': 125000,
                        },
                        {
                          'period': 'monthly',
                          'grossPaise': 4500000,
                          'commissionPaise': 750000,
                          'netPaise': 3750000,
                        },
                      ],
                    },
                  }),
                  200,
                );
              }
              return http.Response(
                jsonEncode({'success': true, 'data': <dynamic>[]}),
                200,
              );
            }),
          ),
        )..roleEnrolment = {'dashboardAccessible': true};
        session.api.accessToken = 'test-token';
        session.api.role = 'fleet_owner';
        session.api.providerMode = 'fleet_owner';

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<DriverSession>.value(
              value: session,
              child: const ProviderAssetsScreen(initialTab: 4),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll until Verification requests is visible
        await tester.scrollUntilVisible(
          find.text('Verification requests'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Expand Verification requests
        await tester.tap(find.text('Verification requests'));
        await tester.pumpAndSettle();

        // Expect mapped titles and StatusPill widgets
        expect(find.text('Fleet Verification'), findsOneWidget);
        expect(find.text('Vehicle Verification'), findsOneWidget);
        expect(find.text('Approved'), findsWidgets);
        expect(find.text('Rejected'), findsWidgets);
        expect(find.text('RC image is blurred'), findsOneWidget);
        expect(find.byType(StatusPill), findsWidgets);

        // Scroll and expand Settlement ledger
        await tester.scrollUntilVisible(
          find.text('Settlement ledger'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settlement ledger'));
        await tester.pumpAndSettle();

        // Expect capitalised period headers
        expect(find.text('Daily settlement'), findsOneWidget);
        expect(find.text('Monthly settlement'), findsOneWidget);

        // Expect separately labelled values: Gross earnings, Commission, Net payout
        expect(find.text('Gross earnings'), findsWidgets);
        expect(find.text('Commission'), findsWidgets);
        expect(find.text('Net payout'), findsWidgets);

        // Expect formatted INR values (150000 paise = ₹1,500)
        expect(find.text('₹1,500'), findsOneWidget);
        expect(find.text('₹250'), findsOneWidget);
        expect(find.text('₹1,250'), findsWidgets);

        session.dispose();
      },
    );
  });
}

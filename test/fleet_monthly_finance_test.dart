import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/fleet_monthly_finance.dart';

void main() {
  testWidgets(
    'monthly Fleet records retain distinct fares, captured payments, net ledger and payout values',
    (tester) async {
      final months = <String>[];
      final api = ApiService(
        client: MockClient((r) async {
          expect(r.url.path, '/provider/fleet-finance');
          expect(r.url.queryParameters.keys, ['month']);
          months.add(r.url.queryParameters['month']!);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'final_fare_revenue': '123.45',
                'completed_trips': 2,
                'missing_final_fares': 1,
                'bookings': 3,
                'captured_payments': '78.90',
                'unsettled_payment_records': 1,
                'unsettled_payment_amount': '44.55',
                'earnings_paise': '9900',
                'commission_paise': '1000',
                'net_ledger_paise': '8900',
                'paid_payout_paise': '4500',
                'pending_payout_paise': '4400',
                'paymentHistory': [],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FleetMonthlyFinance(api: api)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INR 123.45'), findsOneWidget);
      expect(find.text('Captured ride payments: INR 78.90'), findsOneWidget);
      expect(find.textContaining('44.55'), findsOneWidget);
      expect(find.textContaining('89.00'), findsOneWidget);
      expect(find.textContaining('45.00'), findsOneWidget);
      expect(find.textContaining('Estimates are excluded'), findsOneWidget);
      expect(months, hasLength(1));
      final date = DateTime.now().toUtc(),
          previous = DateTime.utc(
            DateTime.now().toUtc().year,
            DateTime.now().toUtc().month - 1,
          );
      final previousMonth =
          '${previous.year}-${previous.month.toString().padLeft(2, '0')}';
      expect(
        months.single,
        '${date.year}-${date.month.toString().padLeft(2, '0')}',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(previousMonth).last);
      await tester.pumpAndSettle();
      expect(months, hasLength(2));
      expect(months.last, previousMonth);
    },
  );
}

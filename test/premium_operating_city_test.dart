import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/fleet_vehicle_category_dialog.dart';

void main() {
  testWidgets(
    'Premium vehicle cannot continue without configured city and preserves exact type',
    (tester) async {
      Map<String, String>? result;
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'sectors': ['premium', 'logistics'],
                'types': [
                  {'sector': 'premium', 'code': 'thar', 'name': 'Thar'},
                ],
                'operatingCities': [
                  {'id': 'patna', 'name': 'Patna'},
                  {'id': 'muzaffarpur', 'name': 'Muzaffarpur'},
                  {'id': 'configured-city', 'name': 'Configured Bihar City'},
                ],
              },
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await selectFleetVehicleCategory(
                    context,
                    api,
                    initial: {'sector': 'premium', 'category': 'thar'},
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configured Bihar City').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, {
        'sector': 'premium',
        'category': 'thar',
        'operatingCityId': 'configured-city',
      });
    },
  );
}

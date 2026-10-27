import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/fleet_model_field.dart';

void main() {
  testWidgets(
    'searches backend models and saves custom identity without a sector',
    (tester) async {
      final requests = <http.Request>[];
      final api = ApiService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': request.method == 'GET'
                  ? [
                      {'make': 'Tata', 'model': '407'},
                    ]
                  : {'make': 'Mahindra', 'model': 'Scorpio'},
            }),
            200,
          );
        }),
      )..accessToken = 'test-token';
      final make = TextEditingController();
      final model = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetModelField(api: api, make: make, model: model),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '407');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(requests.single.url.queryParameters, {'search': '407'});
      await tester.tap(find.text('Tata 407'));
      await tester.pumpAndSettle();
      expect(make.text, 'Tata');
      expect(model.text, '407');
      make.text = 'Mahindra';
      model.text = 'Scorpio';
      await tester.tap(find.text('Add More'));
      await tester.pumpAndSettle();
      expect(find.text('Add More vehicle models'), findsOneWidget);
      await tester.tap(find.text('Save model'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(model.text, 'Scorpio');
      expect(jsonDecode(requests.firstWhere((r) => r.method == 'POST').body), {
        'make': 'Mahindra',
        'model': 'Scorpio',
      });
      await tester.pumpWidget(const SizedBox());
      make.dispose();
      model.dispose();
    },
  );
}

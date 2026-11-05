import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/models/provider_public_id.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/widgets/account_details_card.dart';

void main() {
  test(
    'public IDs are strings of any supported width, without UUID fallback',
    () {
      for (final id in ['100001', '1000000', '100000000000', '1${'0' * 63}']) {
        expect(providerPublicId(id), id);
      }
      for (final invalid in [
        null,
        100001,
        'id-uuid',
        '１２３４５６',
        '000001',
        '100001\n',
      ]) {
        expect(providerPublicId(invalid), isNull);
      }
    },
  );
  testWidgets(
    'account card retrieves numeric ID and keeps resource UUID internal',
    (tester) async {
      final api = ApiService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': '550e8400-e29b-41d4-a716-446655440000',
                'firstName': 'Test',
                'lastName': 'Driver',
                'publicId': '100001',
              },
            }),
            200,
          ),
        ),
      );
      final session = DriverSession(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: Scaffold(body: AccountDetailsCard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Provider ID'), findsOneWidget);
      expect(find.text('100001'), findsOneWidget);
      expect(find.text('550e8400-e29b-41d4-a716-446655440000'), findsNothing);
      session.dispose();
    },
  );
  test('older cached account without publicId stays usable', () {
    final session = DriverSession();
    session.account = {'id': 'legacy-uuid'};
    expect(session.publicId, isNull);
    session.profile = {'publicId': '1000000'};
    expect(session.publicId, '1000000');
    session.dispose();
  });
}

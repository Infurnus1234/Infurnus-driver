import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';

void main() {
  test(
    'old catalog responses fail closed rather than resurfacing legacy arrays',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'sectors': ['logistics'],
                'types': [
                  {'name': 'Old pickup', 'sector': 'logistics', 'code': 'old'},
                ],
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(api.dispose);
      await expectLater(
        VehicleCatalogRepository(api: api).loadCatalog(),
        throwsFormatException,
      );
    },
  );
  test('inactive or unpublished registration options never appear and every read refreshes', () async {
    var calls = 0;
    final api = ApiService(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'selectionCatalogVersion': 2,
              'sectors': ['service'],
              'types': [
                {
                  'id': 'jcb',
                  'name': 'JCB',
                  'code': 'jcb',
                  'sector': 'service',
                  'catalogVisible': true,
                  'registrationActive': true,
                },
                {
                  'id': 'old',
                  'name': 'Old',
                  'code': 'old',
                  'sector': 'service',
                  'catalogVisible': true,
                  'registrationActive': false,
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final repo = VehicleCatalogRepository(api: api);
    expect((await repo.loadCatalog())['types'], hasLength(1));
    expect((await repo.searchVehicles('')).single.modelName, 'JCB');
    expect(calls, 2);
  });
}

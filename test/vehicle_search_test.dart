import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'support/active_catalog_fixture.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';
import 'package:infurnus_driver/widgets/vehicle_selection_search_widget.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  late ApiService api;
  late VehicleCatalogRepository repo;
  late List<Map<String, dynamic>> types;
  setUp(() {
    types = [
      {
        'id': 'ape',
        'code': 'piaggio_ape',
        'name': 'Piaggio Ape',
        'sector': 'logistics',
        'active': true,
      },
      {
        'id': '407',
        'code': 'tata_407',
        'name': 'Tata 407',
        'sector': 'logistics',
        'active': true,
      },
      {
        'id': 'thar',
        'code': 'thar',
        'name': 'Mahindra Thar',
        'sector': 'premium',
        'active': true,
      },
      {
        'id': 'sedan',
        'code': 'sedan',
        'name': 'Sedan',
        'sector': 'passenger',
        'active': true,
      },
      {
        'id': 'disabled',
        'code': 'disabled',
        'name': 'Disabled',
        'catalogVisible': false,
        'sector': 'service',
        'active': false,
      },
    ];
    api = ApiService(
      store: MemorySessionStore(),
      client: activeCatalogClient(
        (request) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {'types': types},
          }),
          200,
        ),
      ),
    );
    repo = VehicleCatalogRepository(api: api);
  });
  tearDown(() => api.dispose());
  test(
    'empty search returns all published server records regardless of pricing',
    () async {
      expect((await repo.searchVehicles('')).map((v) => v.id), [
        'ape',
        '407',
        'thar',
        'sedan',
      ]);
    },
  );
  test('names, identifiers and new Admin types are read from the backend on each refresh', () async {
    expect((await repo.searchVehicles('Tata 407')).single.id, '407');
    types.add({
      'id': 'new',
      'code': 'admin_new',
      'name': 'Admin new option',
      'sector': 'service',
      'active': false,
    });
    expect((await repo.searchVehicles('Admin new')).single.id, 'new');
    types.last['catalogVisible'] = false;
    expect(await repo.searchVehicles('Admin new'), isEmpty);
    types.last['catalogVisible'] = true;
    expect((await repo.searchVehicles('Admin new')).single.id, 'new');
  });
  test('search is case-insensitive', () async {
    expect(
      (await repo.searchVehicles('THAR')).single.id,
      (await repo.searchVehicles('thar')).single.id,
    );
  });
  testWidgets('search widget consumes the authenticated application catalog', (
    tester,
  ) async {
    final session = DriverSession(api: api);
    await tester.pumpWidget(
      ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: Scaffold(
            body: VehicleSelectionSearchWidget(onVehicleSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mahindra Thar'), findsAtLeastNWidgets(1));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}

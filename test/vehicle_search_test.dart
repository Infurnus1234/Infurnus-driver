import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';
import 'package:infurnus_driver/widgets/vehicle_selection_search_widget.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  group('VehicleCatalogRepository Search Tests', () {
    final repo = VehicleCatalogRepository();

    test('Empty search query returns full list', () async {
      final results = await repo.searchVehicles('');
      expect(results, isNotEmpty);
    });

    test(
      'Searching new vehicle categories (3-Wheeler, 407 Cargo, Thar, Etios)',
      () async {
        final goods = await repo.searchVehicles('3-Wheeler');
        expect(goods.map((v) => v.modelName), contains('3-Wheeler (Goods)'));

        final cargo = await repo.searchVehicles('407 Cargo');
        expect(cargo.map((v) => v.modelName), contains('407 Cargo'));

        final thar = await repo.searchVehicles('Thar');
        expect(thar.map((v) => v.modelName), contains('Mahindra Thar'));

        final etios = await repo.searchVehicles('Etios');
        expect(etios.map((v) => v.modelName), contains('Etios (Sedan)'));
      },
    );

    test('Search is case-insensitive', () async {
      final upperResults = await repo.searchVehicles('THAR');
      final lowerResults = await repo.searchVehicles('thar');

      expect(upperResults.length, equals(lowerResults.length));
    });
  });

  group('VehicleSelectionSearchWidget Widget Tests', () {
    testWidgets('VehicleSelectionSearchWidget renders and searches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: Scaffold(
            body: VehicleSelectionSearchWidget(onVehicleSelected: (vehicle) {}),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Thar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mahindra Thar'), findsAtLeastNWidgets(1));
    });
  });
}

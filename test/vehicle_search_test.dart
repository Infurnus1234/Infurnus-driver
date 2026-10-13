import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';
import 'package:infurnus_driver/widgets/vehicle_selection_search_widget.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  group('VehicleCatalogRepository Search Tests', () {
    final repo = VehicleCatalogRepository();

    test('Empty search query returns empty list (does not dump full list)', () async {
      final results = await repo.searchVehicles('');
      expect(results, isEmpty);
    });

    test('Searching new vehicle categories (E-Rickshaw, Force Traveller, 407, Scorpio N)', () async {
      final erickshaw = await repo.searchVehicles('rickshaw');
      expect(erickshaw.map((v) => v.modelName), contains('E-Rickshaw'));

      final force = await repo.searchVehicles('force');
      expect(force.map((v) => v.modelName), contains('Force Traveller'));

      final truck407 = await repo.searchVehicles('407');
      expect(truck407.map((v) => v.modelName), contains('407'));

      final scorpio = await repo.searchVehicles('scorpio');
      expect(scorpio.map((v) => v.modelName), contains('Scorpio N'));
    });

    test('Search is case-insensitive', () async {
      final upperResults = await repo.searchVehicles('SCORPIO');
      final lowerResults = await repo.searchVehicles('scorpio');

      expect(upperResults.length, equals(lowerResults.length));
    });
  });

  group('VehicleSelectionSearchWidget Widget Tests', () {
    testWidgets('VehicleSelectionSearchWidget renders and searches', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: Scaffold(
            body: VehicleSelectionSearchWidget(
              onVehicleSelected: (vehicle) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'scorpio');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scorpio N'), findsAtLeastNWidgets(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/repositories/vehicle_catalog_repository.dart';
import 'package:infurnus_driver/widgets/vehicle_selection_search_widget.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  group('VehicleCatalogRepository Search Tests', () {
    final repo = VehicleCatalogRepository();

    test('Searching "al" returns Alto, Alto K10, Alto 800', () async {
      final results = await repo.searchVehicles('al');
      final names = results.map((v) => v.modelName).toList();

      expect(names, contains('Alto'));
      expect(names, contains('Alto K10'));
      expect(names, contains('Alto 800'));
    });

    test('Searching "for" returns Fortuner, EcoSport, Endeavour, Transit Van', () async {
      final results = await repo.searchVehicles('for');
      final names = results.map((v) => v.modelName).toList();

      expect(names, contains('Fortuner'));
      expect(names, contains('EcoSport'));
      expect(names, contains('Endeavour'));
      expect(names, contains('Transit Van'));
    });

    test('Search is case-insensitive', () async {
      final upperResults = await repo.searchVehicles('ALTO');
      final lowerResults = await repo.searchVehicles('alto');

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

      await tester.enterText(find.byType(TextField), 'al');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Alto'), findsAtLeastNWidgets(1));
    });
  });
}

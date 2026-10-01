import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/repositories/location_catalog_repository.dart';
import 'package:infurnus_driver/widgets/location_search_widget.dart';
import 'package:infurnus_driver/core/theme.dart';

void main() {
  group('LocationCatalogRepository Search Tests', () {
    final repo = LocationCatalogRepository();

    test('Searching "elec" returns Electronic City locations', () async {
      final results = await repo.searchLocations('elec');
      final names = results.map((l) => l.name).toList();

      expect(names, contains('Electronic City Phase 1'));
      expect(names, contains('Electronic City Phase 2'));
    });

    test('Searching "airp" returns BLR Airport', () async {
      final results = await repo.searchLocations('airp');
      final names = results.map((l) => l.name).toList();

      expect(names, contains('Kempegowda International Airport (BLR)'));
    });

    test('Search is case-insensitive', () async {
      final upperResults = await repo.searchLocations('WHITEFIELD');
      final lowerResults = await repo.searchLocations('whitefield');

      expect(upperResults.length, equals(lowerResults.length));
    });
  });

  group('LocationSearchWidget Widget Tests', () {
    testWidgets('LocationSearchWidget renders and filters locations', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: InfurnusTheme.lightTheme,
          home: Scaffold(
            body: LocationSearchWidget(
              onLocationSelected: (loc) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'elec');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Electronic City'), findsAtLeastNWidgets(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/widgets/assigned_vehicle_card.dart';

void main() {
  testWidgets('AssignedVehicleCard times out loading and retry resets timer', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedVehicleCard(
            vehicle: null,
            loading: true,
            retry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Loading assigned vehicle…'), findsOneWidget);
    expect(
      find.text('Could not load assigned vehicle details in time.'),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(
      find.text('Could not load assigned vehicle details in time.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retried, isTrue);
    expect(find.text('Loading assigned vehicle…'), findsOneWidget);
  });

  testWidgets(
    'AssignedVehicleCard never replaces real vehicle with timeout error card',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignedVehicleCard(
              vehicle: const {
                'plateNumber': 'KA 01 AB 1234',
                'make': 'Tata',
                'model': 'Ace',
                'category': 'mini_truck',
                'verificationStatus': 'approved',
                'isActive': true,
              },
              loading: true,
              retry: () {},
            ),
          ),
        ),
      );

      expect(find.text('KA 01 AB 1234'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.text('KA 01 AB 1234'), findsOneWidget);
      expect(
        find.text('Could not load assigned vehicle details in time.'),
        findsNothing,
      );
    },
  );
}

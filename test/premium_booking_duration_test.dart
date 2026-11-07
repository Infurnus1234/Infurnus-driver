import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';

void main() {
  testWidgets(
    'Premium offer shows every exact duration with no radius restriction',
    (tester) async {
      final session = DriverSession();
      addTearDown(session.dispose);
      for (var hours = 1; hours <= 24; hours++) {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: session,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RideOfferCard(
                    ride: {
                      'id': 'premium-$hours',
                      'sector': 'premium',
                      'vehicleCategory': 'sedan',
                      'status': 'searching',
                      'rentalDetails': {'hours': hours},
                      'pickupAddress': 'Selected pickup',
                      'fareEstimate': 100,
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('$hours hours'), findsOneWidget);
        expect(find.textContaining('25 km'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

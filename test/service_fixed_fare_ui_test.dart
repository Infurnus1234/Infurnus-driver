import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';

void main() {
  testWidgets(
    'Service details use the server fixed amount without distance or tax recalculation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RideDetails(
              ride: {
                'id': 'service-test',
                'sector': 'service',
                'vehicleCategory': 'ambulance',
                'status': 'driver_assigned',
                'pickupAddress': 'Patna pickup',
                'fareEstimate': 9999,
                'rideInformation': {
                  'fare': {'amount': 123.45, 'authority': 'booked'},
                },
                'serviceDetails': {
                  'emergencyLevel': 'normal',
                  'description': 'Approved test assistance',
                  'notes': 'Near the gate',
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('Fixed service fare'), findsOneWidget);
      expect(find.textContaining('123.45'), findsOneWidget);
      expect(find.textContaining('9999'), findsNothing);
      expect(find.text('Service details'), findsOneWidget);
      expect(find.textContaining('Approved test assistance'), findsOneWidget);
      expect(
        find.text('Available after customer PIN verification'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Passenger fare wording and final Service amount remain authoritative',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RideDetails(
              ride: {
                'id': 'passenger-test',
                'sector': 'passenger',
                'fareEstimate': 200,
                'status': 'driver_assigned',
              },
            ),
          ),
        ),
      );
      expect(find.text('Estimated fare'), findsOneWidget);
      expect(
        find.text('Available after passenger PIN verification'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RideDetails(
              ride: {
                'id': 'service-test',
                'sector': 'service',
                'finalFare': 123.45,
                'status': 'completed',
                'pinVerified': true,
                'destinationAddress': 'Completed service destination',
                'rideInformation': {
                  'fare': {'amount': 123.45, 'authority': 'final'},
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('Final fare'), findsOneWidget);
      expect(find.textContaining('123.45'), findsOneWidget);
      expect(find.text('Completed service destination'), findsOneWidget);
    },
  );
}

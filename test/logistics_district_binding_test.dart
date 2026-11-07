import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/ride_request_presentation.dart';
import 'package:infurnus_driver/widgets/incoming_ride_request_card.dart';
import 'package:infurnus_driver/widgets/ride_customer_contact_card.dart';
import 'package:infurnus_driver/screens/driver/operations_dashboard.dart';

class DistrictSession extends DriverSession {
  @override
  bool get authenticated => true;
}

Map<String, dynamic> ride() => {
  'id': 'district',
  'sector': 'logistics',
  'status': 'driver_assigned',
  'pinVerified': false,
  'pickupAddress': 'Gandhi Maidan, Patna',
  'destinationDistrict': 'Muzaffarpur',
  'destinationAddress': 'Muzaffarpur',
  'rideInformation': {
    'fare': {'amount': 1500},
    'totalDistance': {'meters': 42000},
  },
  'vehicleName': 'Tata 407',
  'bookingDurationSeconds': 3600,
};
void main() {
  test('Logistics uses district before PIN, same address binding after successful PIN', () {
    final r = ride();
    expect(nativeOffer(r)['drop'], 'Muzaffarpur');
    expect(nativeOffer(r)['pickup'], 'Gandhi Maidan, Patna');
    expect(nativeOffer(r)['fare'], '₹1500');
    r['destinationAddress'] = 'SECRET exact selected building';
    expect(driverDropAddress(r), 'Muzaffarpur');
    r['pinVerified'] = true;
    expect(driverDropAddress(r), 'Muzaffarpur');
    r['status'] = 'in_progress';
    expect(driverDropAddress(r), 'SECRET exact selected building');
  });
  test(
    'missing district never falls back to a stale precise Logistics address',
    () {
      final r = ride()..remove('destinationDistrict');
      r['destinationAddress'] = 'SECRET';
      expect(nativeOffer(r)['drop'], 'Available after PIN verification');
    },
  );
  for (final sector in ['passenger', 'rental', 'premium', 'service']) {
    test('$sector presentation remains unchanged', () {
      final r = ride()
        ..['sector'] = sector
        ..['destinationAddress'] = 'Existing value';
      expect(driverDropAddress(r), 'Existing value');
    });
  }
  testWidgets(
    'existing request card keeps identical layout/style/actions with district data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = ride();
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              child: IncomingRideRequestCard(
                ride: r,
                remaining: const Duration(seconds: 25),
                accept: () {},
                reject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      final beforeAccept = tester.getRect(
        find.widgetWithText(FilledButton, 'Accept'),
      );
      final beforeReject = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Reject'),
      );
      final beforeCard = tester.getRect(find.byType(IncomingRideRequestCard));
      final beforeStyles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style)
          .toList();
      expect(find.text('Muzaffarpur'), findsOneWidget);
      expect(find.text('Drop'), findsOneWidget);
      expect(find.text('Ride Price'), findsOneWidget);
      r['pinVerified'] = true;
      r['status'] = 'in_progress';
      r['destinationAddress'] = 'Selected Building';
      await tester.pumpWidget(screen());
      expect(find.text('Selected Building'), findsOneWidget);
      expect(
        tester.getRect(find.widgetWithText(FilledButton, 'Accept')),
        beforeAccept,
      );
      expect(
        tester.getRect(find.widgetWithText(OutlinedButton, 'Reject')),
        beforeReject,
      );
      expect(tester.getRect(find.byType(IncomingRideRequestCard)), beforeCard);
      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.style).toList(),
        beforeStyles,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'accepted-trip existing address line changes only Logistics drop data',
    (tester) async {
      final session = DistrictSession()..currentTrip = ride();
      Widget screen() => ChangeNotifierProvider<DriverSession>.value(
        value: session,
        child: const MaterialApp(
          home: Scaffold(body: RideCustomerContactCard(compact: true)),
        ),
      );
      await tester.pumpWidget(screen());
      expect(find.text('Muzaffarpur'), findsOneWidget);
      session.currentTrip = {
        ...session.currentTrip!,
        'pinVerified': true,
        'status': 'in_progress',
        'destinationAddress': 'Selected exact destination',
      };
      session.notifyListeners();
      await tester.pump();
      expect(find.text('Selected exact destination'), findsOneWidget);
      session.currentTrip = {...session.currentTrip!, 'sector': 'premium'};
      session.notifyListeners();
      await tester.pump();
      expect(find.text('Gandhi Maidan, Patna'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'existing Drop field in ride details switches district to full address without new widgets',
    (tester) async {
      final r = ride();
      Widget screen() => MaterialApp(
        home: Scaffold(body: RideDetails(ride: r)),
      );
      await tester.pumpWidget(screen());
      expect(find.text('Drop'), findsOneWidget);
      expect(find.text('Muzaffarpur'), findsOneWidget);
      r['pinVerified'] = true;
      r['status'] = 'in_progress';
      r['destinationAddress'] = 'Selected exact destination';
      await tester.pumpWidget(screen());
      expect(find.text('Drop'), findsOneWidget);
      expect(find.text('Selected exact destination'), findsOneWidget);
    },
  );
}

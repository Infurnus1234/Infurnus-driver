import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/models/app_models.dart';
import 'package:infurnus_driver/providers/app_state.dart';

void main() {
  group('Feature 1 — 10% Ride Commission Tests', () {
    test('Calculates 10% commission and 90% driver net earning correctly for ₹106.00', () {
      final booking = BookingModel(
        id: 'BK-100',
        bookingType: 'Ride',
        pickupLocation: 'A',
        dropoffLocation: 'B',
        customerName: 'Test Customer',
        customerPhone: '+919999999999',
        distanceKm: 5.0,
        fareAmount: 106.00,
        createdAt: 'Just now',
      );

      expect(booking.fareAmountPaise, equals(10600));
      expect(booking.commissionPaise, equals(1060));
      expect(booking.driverNetEarningPaise, equals(9540));
      expect(booking.commissionAmount, closeTo(10.60, 0.01));
      expect(booking.driverNetEarning, closeTo(95.40, 0.01));
    });

    test('Calculates commission for different final fares accurately', () {
      final booking = BookingModel(
        id: 'BK-101',
        bookingType: 'Ride',
        pickupLocation: 'A',
        dropoffLocation: 'B',
        customerName: 'Test Customer',
        customerPhone: '+919999999999',
        distanceKm: 10.0,
        fareAmount: 450.00,
        createdAt: 'Just now',
      );

      expect(booking.fareAmountPaise, equals(45000));
      expect(booking.commissionPaise, equals(4500));
      expect(booking.driverNetEarningPaise, equals(40500));
      expect(booking.commissionAmount, closeTo(45.00, 0.01));
      expect(booking.driverNetEarning, closeTo(405.00, 0.01));
    });
  });

  group('Feature 2 — Ride Accept / Reject & Smart Matching Tests', () {
    test('AppState eligibleBookings filters bookings based on driver availability and vehicle category', () {
      final appState = AppState();

      // Initially offline, should return empty eligible bookings
      expect(appState.isOnline, isFalse);
      expect(appState.eligibleBookings.length, equals(0));

      // Toggle online status
      appState.toggleOnlineStatus();
      expect(appState.isOnline, isTrue);

      // With driver assigned vehicle category 'Truck' (VEH-101 in initial state), logistics bookings should match
      final eligible = appState.eligibleBookings;
      expect(eligible.any((b) => b.bookingType == 'Logistics'), isTrue);
    });

    test('Accepting a booking updates booking status to Accepted', () {
      final appState = AppState();
      appState.toggleOnlineStatus();

      final bookingId = appState.bookings.first.id;
      appState.acceptBooking(bookingId);

      final accepted = appState.bookings.firstWhere((b) => b.id == bookingId);
      expect(accepted.status, equals('Accepted'));
    });
  });
}

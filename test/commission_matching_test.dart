import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/models/app_models.dart';
import 'package:infurnus_driver/providers/app_state.dart';

void main() {
  group('INFURNUS Payment & 10% Commission Integration Tests', () {
    test('Calculates base fare, 18% GST, 10% base-fare commission, and driver net earning correctly for ₹100 base fare', () {
      final booking = BookingModel(
        id: 'BK-PAY-01',
        bookingType: 'Ride',
        pickupLocation: 'Koramangala',
        dropoffLocation: 'Airport',
        customerName: 'Rahul Sharma',
        customerPhone: '+919876543210',
        distanceKm: 12.0,
        baseFare: 100.00, // Base ₹100
        taxRate: 0.18, // 18% GST
        createdAt: 'Just now',
      );

      // Base Fare = 10000 paise
      expect(booking.baseFarePaise, equals(10000));
      // GST (18%) = 1800 paise (₹18.00)
      expect(booking.gstAmountPaise, equals(1800));
      expect(booking.gstAmount, closeTo(18.00, 0.01));
      // Total Customer Fare = 11800 paise (₹118.00)
      expect(booking.totalCustomerFarePaise, equals(11800));
      expect(booking.totalCustomerFare, closeTo(118.00, 0.01));
      // Infurnus Commission (10% of Base Fare) = 1000 paise (₹10.00)
      expect(booking.commissionPaise, equals(1000));
      expect(booking.commissionAmount, closeTo(10.00, 0.01));
      // Driver Net Earning (90% of Base Fare) = 9000 paise (₹90.00)
      expect(booking.driverNetEarningPaise, equals(9000));
      expect(booking.driverNetEarning, closeTo(90.00, 0.01));
    });
  });

  group('Feature 2 — Ride Accept / Reject & Smart Matching Tests', () {
    test('AppState eligibleBookings filters bookings based on driver availability and vehicle category', () {
      final appState = AppState(demo: true);

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
      final appState = AppState(demo: true);
      appState.toggleOnlineStatus();

      final bookingId = appState.bookings.first.id;
      appState.acceptBooking(bookingId);

      final accepted = appState.bookings.firstWhere((b) => b.id == bookingId);
      expect(accepted.status, equals('Accepted'));
    });
  });
}

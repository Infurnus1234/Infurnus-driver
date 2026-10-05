import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class RideRequestsScreen extends StatelessWidget {
  const RideRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final bookings = appState.bookings;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Ride & Booking Requests'),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: bookings.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final booking = bookings[index];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#${booking.id} • ${booking.bookingType}',
                        style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '₹ ${booking.fareAmount}',
                        style: const TextStyle(color: InfurnusTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Pickup: ${booking.pickupLocation}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 13)),
                  Text('Dropoff: ${booking.dropoffLocation}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 13)),
                  if (booking.goodsDescription != null) ...[
                    const SizedBox(height: 4),
                    Text('Goods: ${booking.goodsDescription}', style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status: ${booking.status}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                          foregroundColor: Colors.white,
                          minimumSize: const Size(110, 36),
                        ),
                        onPressed: () {
                          appState.acceptBooking(booking.id);
                          context.push('/driver/ride-details');
                        },
                        child: const Text('View Details', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

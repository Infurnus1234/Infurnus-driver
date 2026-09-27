import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class LogisticsOperationsScreen extends StatelessWidget {
  const LogisticsOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final bookings = appState.bookings.where((b) => b.bookingType == 'Logistics' || b.bookingType == 'Parcel').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Logistics Operations')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.accentOrange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2, color: InfurnusTheme.accentOrange, size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Logistics Workflow Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Booking -> Acceptance -> Route -> Pickup -> Goods Tracking -> Delivery', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Logistics Cargo Shipments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...bookings.map((booking) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Shipment #${booking.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: InfurnusTheme.infoBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(booking.status.toUpperCase(), style: const TextStyle(color: InfurnusTheme.infoBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Route Allocation: ${booking.routeDetails ?? "Direct Transit"}', style: const TextStyle(color: InfurnusTheme.accentOrange, fontSize: 12)),
                    Text('Goods: ${booking.goodsDescription ?? "General Merchandise"}', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
                    Text('Pickup: ${booking.pickupLocation}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    Text('Delivery: ${booking.dropoffLocation}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fare: ₹${booking.fareAmount}', style: const TextStyle(color: InfurnusTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(110, 34)),
                          onPressed: () {
                            appState.updateBookingStatus(booking.id, 'Delivered');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delivery confirmed for shipment #${booking.id}')),
                            );
                          },
                          child: const Text('Confirm Delivery', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class RideDetailsScreen extends StatelessWidget {
  const RideDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final booking = appState.bookings.first;

    return Scaffold(
      appBar: AppBar(title: Text('Ride Details #${booking.id}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map View Simulation Container
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.accentOrange.withOpacity(0.4)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_outlined, size: 48, color: InfurnusTheme.accentOrange),
                          const SizedBox(height: 8),
                          const Text(
                            'LIVE GPS ROUTE NAVIGATION MAP',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Route: ${booking.routeDetails ?? "NH 44 -> Outer Ring Road"}',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: InfurnusTheme.infoBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${booking.distanceKm} km',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Customer & Pickup Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer & Contact',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text('Customer Name: ${booking.customerName}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text('Phone: ${booking.customerPhone}', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.successGreen),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling customer ${booking.customerPhone}')),
                        );
                      },
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call Customer'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Goods & Cargo Details (Requirement Section 8)
              if (booking.goodsDescription != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: InfurnusTheme.primaryDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Goods & Cargo Information',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(booking.goodsDescription!, style: const TextStyle(color: InfurnusTheme.accentOrange, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Logistics Delivery Status Controller
              const Text(
                'Update Delivery Status',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Column(
                children: [
                  _statusButton(context, appState, booking.id, 'In Transit', Icons.directions_car),
                  const SizedBox(height: 8),
                  _statusButton(context, appState, booking.id, 'Goods Picked Up', Icons.inventory_2),
                  const SizedBox(height: 8),
                  _statusButton(context, appState, booking.id, 'Delivered', Icons.check_circle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusButton(BuildContext context, AppState appState, String id, String statusLabel, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          appState.updateBookingStatus(id, statusLabel);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated trip status to "$statusLabel"')),
          );
        },
        icon: Icon(icon, size: 18),
        label: Text('Mark as "$statusLabel"'),
      ),
    );
  }
}

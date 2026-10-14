import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class OnRideScreen extends StatelessWidget {
  const OnRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final booking = appState.bookings.first;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Trip in Progress'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFE2E8F0),
                child: Stack(
                  children: [
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation, size: 64, color: InfurnusTheme.infoBlue),
                          SizedBox(height: 8),
                          Text('LIVE ROUTE TO DROP OFF', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Drop Off Destination', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
                                  Text(booking.dropoffLocation, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Text('12 min • 5.8 km', style: TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Sheet Info & Actions (Wireframe Screen 15)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: InfurnusTheme.greenLight,
                              child: Text('A', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking.customerName, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
                                const Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 14),
                                    SizedBox(width: 4),
                                    Text('4.8', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹ ${booking.totalCustomerFare.toStringAsFixed(0)}', style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: InfurnusTheme.greenLight, borderRadius: BorderRadius.circular(6)),
                              child: Text(booking.paymentMethod.toUpperCase(), style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () {},
                            icon: const Icon(Icons.warning, size: 16),
                            label: const Text('Emergency'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: InfurnusTheme.buttonBlack, side: const BorderSide(color: InfurnusTheme.buttonBlack)),
                            onPressed: () {},
                            icon: const Icon(Icons.support_agent, size: 16),
                            label: const Text('Support'),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InfurnusTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () {
                        appState.updateBookingStatus(booking.id, 'Delivered');
                        context.push('/driver/trip-completed');
                      },
                      child: const Text('Complete Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

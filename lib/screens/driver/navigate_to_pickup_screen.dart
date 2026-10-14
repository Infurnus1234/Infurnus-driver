import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class NavigateToPickupScreen extends StatelessWidget {
  const NavigateToPickupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final booking = appState.bookings.first;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Navigate to Pickup'),
      body: SafeArea(
        child: Column(
          children: [
            // Map view placeholder
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
                          Icon(Icons.map, size: 64, color: InfurnusTheme.primaryGreen),
                          SizedBox(height: 8),
                          Text('LIVE NAVIGATION MAP TO PICKUP', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
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
                            const Icon(Icons.my_location, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pickup Location', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
                                  Text(booking.pickupLocation, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Text('2.4 km away • 6 min', style: TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
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

            // Bottom Sheet Info & Actions (Wireframe Screen 14)
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
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const CircleAvatar(backgroundColor: InfurnusTheme.greenLight, child: Icon(Icons.message, color: InfurnusTheme.primaryGreen, size: 18)),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const CircleAvatar(backgroundColor: InfurnusTheme.greenLight, child: Icon(Icons.phone, color: InfurnusTheme.primaryGreen, size: 18)),
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
                        appState.updateBookingStatus(booking.id, 'In Transit');
                        context.push('/driver/on-ride');
                      },
                      child: const Text('Arrived at Pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

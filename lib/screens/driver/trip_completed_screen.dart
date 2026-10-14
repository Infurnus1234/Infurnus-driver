import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class TripCompletedScreen extends StatelessWidget {
  const TripCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final booking = appState.bookings.first;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 40,
                backgroundColor: InfurnusTheme.primaryGreen,
                child: Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Trip Completed!',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '₹ ${booking.driverNetEarning.toStringAsFixed(2)}',
                style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 32),

              // Fare breakdown card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    _fareRow('Base Fare', '₹ ${booking.baseFare.toStringAsFixed(2)}'),
                    const SizedBox(height: 10),
                    _fareRow('Distance (${booking.distanceKm} km)', '₹ ${(booking.baseFare * 0.35).toStringAsFixed(2)}'),
                    const Divider(color: Colors.white24, height: 24),
                    _fareRow('Total Driver Earnings (90%)', '₹ ${booking.driverNetEarning.toStringAsFixed(2)}', isBold: true),
                  ],
                ),
              ),
              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  context.go('/driver/dashboard');
                },
                child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fareRow(String label, String amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.white : Colors.white70,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: isBold ? InfurnusTheme.primaryGreen : Colors.white,
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

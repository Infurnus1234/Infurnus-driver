import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_models.dart';
import '../../core/theme.dart';
import '../../widgets/mode_switch_header.dart';
import '../../widgets/custom_drawer.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isOnline = appState.isOnline;
    final eligibleBookings = appState.eligibleBookings;
    final bookings = appState.bookings;
    final activeBooking = bookings.firstWhere(
      (b) => b.status == 'Accepted' || b.status == 'In Transit',
      orElse: () => bookings.first,
    );

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ModeSwitchHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Online / Offline Toggle Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isOnline ? InfurnusTheme.greenLight : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnline ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isOnline ? InfurnusTheme.primaryGreen : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline ? 'ONLINE & READY' : 'OFFLINE',
                                    style: TextStyle(
                                      color: isOnline ? InfurnusTheme.primaryGreen : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOnline
                                    ? 'Receiving matched vehicle-category bookings'
                                    : 'Toggle ON to start accepting rides',
                                style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                          Switch(
                            value: isOnline,
                            activeThumbColor: InfurnusTheme.primaryGreen,
                            onChanged: (_) => appState.toggleOnlineStatus(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Banner
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            title: 'Today Earnings (Net)',
                            value: '₹ 1,665.00',
                            subtext: 'After 10% Platform Fee',
                            icon: Icons.account_balance_wallet,
                            color: InfurnusTheme.primaryGreen,
                            onTap: () => context.push('/driver/earnings'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            title: 'Trips Completed',
                            value: '4 Rides',
                            subtext: 'Matched Category',
                            icon: Icons.check_circle_outline,
                            color: InfurnusTheme.infoBlue,
                            onTap: () => context.push('/driver/rides'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Assigned Vehicle Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.minor_crash, color: InfurnusTheme.primaryGreen, size: 32),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Vehicle (Smart Match Active)',
                                  style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 11),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tata Ace EV (KA 01 EV 8899)',
                                  style: TextStyle(
                                    color: InfurnusTheme.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              minimumSize: const Size(70, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => context.push('/driver/assigned-vehicle'),
                            child: const Text('Details', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Eligible Booking Requests Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Matched Requests (10% Comm.)',
                            style: TextStyle(color: InfurnusTheme.textDark, fontSize: 14, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/driver/rides'),
                          child: const Text('See All', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (!isOnline) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'You are currently OFFLINE. Toggle ON above to receive matched bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: InfurnusTheme.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ] else if (eligibleBookings.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'No eligible booking requests matching your vehicle category.',
                            style: TextStyle(color: InfurnusTheme.textMuted),
                          ),
                        ),
                      ),
                    ] else ...[
                      ...eligibleBookings.map((booking) => _bookingCard(context, appState, booking)),
                    ],

                    const SizedBox(height: 24),

                    // Active Trip Card
                    const Text(
                      'Current Active Ride',
                      style: TextStyle(color: InfurnusTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    _activeTripCard(context, activeBooking),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(subtext, style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(BuildContext context, AppState appState, BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InfurnusTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: InfurnusTheme.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.bookingType.toUpperCase(),
                  style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Final Fare: ₹ ${booking.fareAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Net Earning (90%): ₹ ${booking.driverNetEarning.toStringAsFixed(2)}',
                    style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.pickupLocation,
                  style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.dropoffLocation,
                  style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: InfurnusTheme.buttonBlack,
                    side: const BorderSide(color: InfurnusTheme.buttonBlack),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Booking #${booking.id} rejected.')),
                    );
                  },
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    appState.acceptBooking(booking.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accepted Booking #${booking.id}! Net Earning: ₹${booking.driverNetEarning.toStringAsFixed(2)}')),
                    );
                    context.push('/driver/ride-details');
                  },
                  child: const Text('Accept Ride'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeTripCard(BuildContext context, BookingModel booking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking #${booking.id}',
                style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: InfurnusTheme.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status.toUpperCase(),
                  style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${booking.customerName} (${booking.customerPhone})',
            style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Driver Net Payout (90%): ₹ ${booking.driverNetEarning.toStringAsFixed(2)} (10% Fee ₹${booking.commissionAmount.toStringAsFixed(2)})',
            style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.push('/driver/ride-details'),
            icon: const Icon(Icons.navigation, size: 18),
            label: const Text('Live Navigation & Trip Status'),
          ),
        ],
      ),
    );
  }
}

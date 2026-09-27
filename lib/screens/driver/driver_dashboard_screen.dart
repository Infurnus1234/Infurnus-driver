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
    final user = appState.currentUser;
    final isOnline = appState.isOnline;
    final bookings = appState.bookings;
    final pendingBookings = bookings.where((b) => b.status == 'Pending').toList();
    final activeBooking = bookings.firstWhere(
      (b) => b.status == 'Accepted' || b.status == 'In Transit',
      orElse: () => bookings.first,
    );

    return Scaffold(
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
                        color: isOnline
                            ? InfurnusTheme.successGreen.withOpacity(0.15)
                            : InfurnusTheme.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOnline ? InfurnusTheme.successGreen : Colors.white12,
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
                                      color: isOnline ? InfurnusTheme.successGreen : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isOnline ? 'ONLINE & READY' : 'OFFLINE',
                                    style: TextStyle(
                                      color: isOnline ? InfurnusTheme.successGreen : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOnline
                                    ? 'Receiving ride & logistics requests'
                                    : 'Toggle ON to start accepting rides',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                          Switch(
                            value: isOnline,
                            activeColor: InfurnusTheme.successGreen,
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
                            title: 'Today Earnings',
                            value: '₹ 1,850.00',
                            icon: Icons.account_balance_wallet,
                            color: InfurnusTheme.accentOrange,
                            onTap: () => context.push('/driver/earnings'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            title: 'Trips Completed',
                            value: '4 Rides',
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
                        color: InfurnusTheme.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.minor_crash, color: InfurnusTheme.accentOrange, size: 32),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Vehicle',
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tata Ace EV (KA 01 EV 8899)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
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

                    // Pending Ride Requests Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Booking Requests',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.push('/driver/rides'),
                          child: const Text('See All', style: TextStyle(color: InfurnusTheme.accentOrange)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (pendingBookings.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: InfurnusTheme.primaryDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No pending booking requests nearby.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ] else ...[
                      ...pendingBookings.map((booking) => _bookingCard(context, appState, booking)),
                    ],

                    const SizedBox(height: 24),

                    // Active Trip Card
                    const Text(
                      'Current Active Ride',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: InfurnusTheme.primaryDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
        color: InfurnusTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InfurnusTheme.accentOrange.withOpacity(0.3)),
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
                  color: InfurnusTheme.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.bookingType.toUpperCase(),
                  style: const TextStyle(color: InfurnusTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '₹ ${booking.fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: InfurnusTheme.successGreen, fontSize: 18, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
                  onPressed: () {},
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    appState.acceptBooking(booking.id);
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
        color: InfurnusTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InfurnusTheme.infoBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking #${booking.id}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: InfurnusTheme.infoBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  booking.status.toUpperCase(),
                  style: const TextStyle(color: InfurnusTheme.infoBlue, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${booking.customerName} (${booking.customerPhone})',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: InfurnusTheme.infoBlue,
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

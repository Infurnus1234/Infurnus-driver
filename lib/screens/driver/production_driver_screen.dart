import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../widgets/operations.dart';
import '../../widgets/trip_map.dart';

class ProductionDriverScreen extends StatelessWidget {
  const ProductionDriverScreen({super.key});
  Future<void> _next(
    BuildContext context,
    DriverSession session,
    String status,
  ) async {
    String? pin;
    if (status == 'in_progress') {
      final controller = TextEditingController();
      pin = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Customer pickup PIN'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'PIN provided by customer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Verify & start'),
            ),
          ],
        ),
      );
      // The closing dialog still owns its text field until its exit transition ends.
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
      if (pin == null || !context.mounted) return;
    }
    if (status == 'completed') {
      if (!await confirmOperation(
        context,
        'Complete this trip?',
        'Confirm that the passenger or shipment has reached the destination.',
      )) {
        return;
      }
    }
    await session.transition(status, pin: pin);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final trip = session.currentTrip;
    const nextStatus = {
      'driver_assigned': 'driver_arriving',
      'driver_arriving': 'driver_arrived',
      'driver_arrived': 'in_progress',
      'in_progress': 'completed',
    };
    const labels = {
      'driver_arriving': 'Start toward pickup',
      'driver_arrived': 'Arrived at pickup',
      'in_progress': 'Verify PIN & start trip',
      'completed': 'Complete trip',
    };
    final next = nextStatus[trip?['status']];
    final name =
        session.account?['firstName'] ??
        session.profile?['firstName'] ??
        'Driver';
    return Scaffold(
      appBar: AppBar(
        title: Text('$name · Driver'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Safety & settings',
            onPressed: () => context.push('/safety'),
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await session.refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(Ops.padding),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (session.busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Updating operational state',
                ),
              if (session.api.isTestOnboarding || session.isPreview)
                const OpsPanel(
                  title: 'Development session',
                  child: Text(
                    'This session does not verify production readiness.',
                  ),
                ),
              if (session.error != null)
                OpsError(session.error!, retry: session.refresh),
              OpsPanel(
                title: session.online ? 'Online' : 'Offline',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        session.online
                            ? 'Available for dispatch'
                            : 'Go online to receive offers',
                      ),
                      subtitle: Text('Realtime: ${session.realtimeStatus}'),
                      value: session.online,
                      onChanged: session.busy ? null : session.setOnline,
                    ),
                    Text(
                      'Verification: ${session.profile?['verificationStatus'] ?? 'Unknown'}',
                    ),
                    Text(
                      'Vehicle: ${session.assignedVehicle?['plateNumber'] ?? 'Not assigned'}',
                    ),
                    if (session.api.role == 'driver_fleet_owner')
                      TextButton.icon(
                        onPressed: session.busy
                            ? null
                            : () async {
                                final ok = await session.switchMode(
                                  'fleet_owner',
                                );
                                if (context.mounted && ok) {
                                  context.go(session.landingPath);
                                }
                              },
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Switch to fleet owner'),
                      ),
                  ],
                ),
              ),
              const TripMap(),
              if (trip != null)
                OpsPanel(
                  title: 'Active trip · ${trip['status']}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RideDetails(ride: trip),
                      if (next != null)
                        FilledButton(
                          onPressed: session.busy
                              ? null
                              : () => _next(context, session, next),
                          child: Text(labels[next]!),
                        ),
                    ],
                  ),
                ),
              OpsPanel(
                title: 'Trip history summary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.history?['totalEarnings'] == null
                          ? 'Earnings unavailable'
                          : inr(
                              (num.tryParse(
                                        session.history!['totalEarnings']
                                            .toString(),
                                      ) ??
                                      0) *
                                  100,
                            ),
                      style: Ops.metric,
                    ),
                    Text(
                      '${session.history?['totalTrips'] ?? '—'} trips · History total, not available wallet balance',
                    ),
                    TextButton(
                      onPressed: () => context.go('/driver/earnings'),
                      child: const Text('View settlement earnings'),
                    ),
                  ],
                ),
              ),
              Text(
                'Ride offers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (session.rides.isEmpty)
                OpsEmpty(
                  session.online
                      ? 'No ride offers right now.'
                      : 'You are offline.',
                ),
              for (final ride in session.rides) RideOfferCard(ride: ride),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideDetails extends StatelessWidget {
  final Map ride;
  const _RideDetails({required this.ride});
  @override
  Widget build(BuildContext context) {
    final fare = ride['finalFare'] ?? ride['fareEstimate'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pickup · ${ride['pickupAddress'] ?? 'Not provided'}'),
        const SizedBox(height: 8),
        Text('Destination · ${ride['destinationAddress'] ?? 'Not disclosed'}'),
        const SizedBox(height: 8),
        Text('Category · ${ride['vehicleCategory'] ?? 'Not provided'}'),
        if (fare != null)
          Text(
            '${ride['finalFare'] == null ? 'Estimated fare' : 'Final fare'} · ₹$fare',
          ),
        const SizedBox(height: 8),
        SelectableText('Ride ${ride['id']}'),
        const SizedBox(height: 12),
      ],
    );
  }
}

class RideOfferCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const RideOfferCard({super.key, required this.ride});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final expiry = DateTime.tryParse(
      ride['dispatchExpiresAt']?.toString() ?? '',
    );
    final expired = expiry != null && !expiry.isAfter(DateTime.now());
    return OpsPanel(
      title: expired ? 'Offer expired' : 'Ride offer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RideDetails(ride: ride),
          if (expiry != null) Text('Expires ${expiry.toLocal()}'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: session.busy || expired
                    ? null
                    : () => session.decline(ride['id'] as String),
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: session.busy || expired
                    ? null
                    : () => session.accept(ride['id'] as String),
                child: const Text('Accept offer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ServerRideRequestsScreen extends StatelessWidget {
  const ServerRideRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ride offers')),
      body: RefreshIndicator(
        onRefresh: () async {
          await session.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(Ops.padding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (session.error != null)
              OpsError(session.error!, retry: session.refresh),
            if (session.rides.isEmpty) const OpsEmpty('No current offers.'),
            for (final ride in session.rides) RideOfferCard(ride: ride),
          ],
        ),
      ),
    );
  }
}

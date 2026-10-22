import '../../widgets/assigned_vehicle_card.dart';
import '../../widgets/ride_pin_dialog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../widgets/operations.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/reference_components.dart';

class OperationsDashboard extends StatelessWidget {
  const OperationsDashboard({super.key});
  Future<void> _next(
    BuildContext context,
    DriverSession session,
    String status,
  ) async {
    if (status == 'in_progress') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => RidePinDialog(session: session),
      );
      return;
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
    await session.transition(status);
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
      'completed': 'Complete Ride',
    };
    final next = nextStatus[trip?['status']];
    final name =
        session.account?['firstName'] ??
        session.profile?['firstName'] ??
        'Driver';
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: InfurnusBrand(name: name.toString()),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trip != null && next != null)
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: next == 'completed' ? null : Ops.darkButton,
                    onPressed: session.busy
                        ? null
                        : () => _next(context, session, next),
                    child: Text(labels[next]!),
                  ),
                ),
              ),
            ),
          const DriverBottomNav(currentIndex: 0),
        ],
      ),
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
              if (session.isPreview)
                const OpsPanel(
                  title: 'TEST PREVIEW — NOT AUTHENTICATED',
                  child: Text(
                    'Sample data is enabled only in this debug preview.',
                  ),
                ),
              if (session.api.isTestOnboarding)
                const OpsPanel(
                  title: 'Development session',
                  child: Text(
                    'This session does not verify production readiness.',
                  ),
                ),
              if (session.error != null)
                OpsError(session.error!, retry: session.refresh),
              if (session.refreshWarning != null)
                OpsError(session.refreshWarning!, retry: session.refresh),
              if (session.api.hasFleetRole && trip == null)
                const ModeSelector(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: session.online || trip != null
                      ? Ops.actionPrimary
                      : const Color(0xFF7D847F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      session.online
                          ? Icons.check_circle_outline
                          : Icons.power_settings_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trip != null
                            ? "On a trip"
                            : session.online
                            ? "You're Online"
                            : "You're Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: session.online,
                      activeTrackColor: const Color(0xFF007C3C),
                      onChanged: session.busy ? null : session.setOnline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (session.online && trip == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Searching for rides nearby…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Ops.textSecondary, fontSize: 12),
                  ),
                ),
              AssignedVehicleCard(
                vehicle: session.assignedVehicle,
                loading: session.busy,
                canManage: trip == null && !session.online,
                retry: session.refresh,
              ),
              if (!session.isPreview) const TripMap(compact: true),
              if (session.isPreview)
                const OpsEmpty(
                  'Maps require an authenticated device session.',
                  icon: Icons.map_outlined,
                ),
              if (!session.online && trip == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 36,
                          color: Ops.textPrimary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "You're Offline",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Go online to receive new ride requests.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Ops.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: session.busy
                              ? null
                              : () => session.setOnline(true),
                          child: const Text('Go Online'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (trip != null)
                OpsPanel(
                  title: trip['status'] == 'in_progress'
                      ? 'On Ride'
                      : trip['status'] == 'driver_arrived'
                      ? 'At the pickup'
                      : 'Navigate to Pickup',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RideDetails(ride: trip),
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Ops.error,
                            ),
                            onPressed: () => context.push('/safety'),
                            icon: const Icon(
                              Icons.health_and_safety_outlined,
                              size: 18,
                            ),
                            label: const Text('Safety'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => context.push('/support-tickets'),
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: const Text('Support'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (trip == null) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

class RideDetails extends StatelessWidget {
  final Map ride;
  const RideDetails({super.key, required this.ride});
  @override
  Widget build(BuildContext context) {
    final fare = ride['finalFare'] ?? ride['fareEstimate'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.trip_origin, color: Ops.success, size: 20),
          title: const Text(
            'Pickup',
            style: TextStyle(fontSize: 11, color: Ops.textSecondary),
          ),
          subtitle: Text(
            ride['pickupAddress']?.toString() ?? 'Not provided',
            style: const TextStyle(
              color: Ops.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(
            Icons.location_on_outlined,
            color: Ops.error,
            size: 20,
          ),
          title: const Text(
            'Drop',
            style: TextStyle(fontSize: 11, color: Ops.textSecondary),
          ),
          subtitle: Text(
            ride['pinVerified'] == true &&
                    ['in_progress', 'completed'].contains(ride['status'])
                ? ride['destinationAddress']?.toString() ?? 'Not provided'
                : 'Available after passenger PIN verification',
            style: const TextStyle(
              color: Ops.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (fare != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ride['finalFare'] == null ? 'Estimated fare' : 'Final fare',
                  style: const TextStyle(color: Ops.textSecondary),
                ),
                Text(
                  inrRupees(fare),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Trip details', style: TextStyle(fontSize: 12)),
          children: [
            ListTile(
              title: Text(
                'Category: ${ride['vehicleCategory'] ?? 'Not provided'}',
              ),
              subtitle: SelectableText('Ride ${ride['id']}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
      title: expired ? 'Offer expired' : 'New Ride Request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RideDetails(ride: ride),
          if (expiry != null) Text('Expires ${expiry.toLocal()}'),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: Ops.criticalButton,
                  onPressed: session.busy || expired
                      ? null
                      : () => session.decline(ride['id'] as String),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: session.busy || expired
                      ? null
                      : () => session.accept(ride['id'] as String),
                  child: const Text('Accept'),
                ),
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

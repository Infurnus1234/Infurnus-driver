import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../services/api_service.dart';

/// Driver operations use server-confirmed identity, eligibility and ride state.
class ProductionDriverScreen extends StatefulWidget {
  const ProductionDriverScreen({super.key});
  @override
  State<ProductionDriverScreen> createState() => _ProductionDriverScreenState();
}

class _ProductionDriverScreenState extends State<ProductionDriverScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _places = [];
  Map<String, dynamic>? _route;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _next(DriverSession session, String status) async {
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
            decoration: const InputDecoration(
              labelText: 'PIN provided by customer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Verify and start'),
            ),
          ],
        ),
      );
      // The closing dialog finishes its animation before the controller is disposed.
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      );
      if (pin == null) return;
    }
    await session.transition(status, pin: pin);
    if (mounted) setState(() => _route = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    if (!session.authenticated ||
        (!session.busy && !session.dashboardAllowed)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(session.landingPath);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final trip = session.currentTrip;
    final profile = session.profile ?? {};
    const nextStatus = {
      'driver_assigned': 'driver_arriving',
      'driver_arriving': 'driver_arrived',
      'driver_arrived': 'in_progress',
      'in_progress': 'completed',
    };
    const actionLabel = {
      'driver_arriving': 'On the way to pickup',
      'driver_arrived': 'Arrived at pickup',
      'in_progress': 'Verify PIN and start trip',
      'completed': 'Complete trip',
    };
    final next = nextStatus[trip?['status']];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Owned vehicles & documents',
            icon: const Icon(Icons.local_shipping),
            onPressed: session.busy
                ? null
                : () => context.go('/provider-assets'),
          ),
          if (session.api.hasFleetRole)
            IconButton(
              tooltip: 'Fleet mode',
              icon: const Icon(Icons.swap_horiz),
              onPressed: session.busy
                  ? null
                  : () async {
                      final ok = await session.switchMode('fleet_owner');
                      if (context.mounted && ok) {
                        context.go(session.landingPath);
                      }
                    },
            ),
          IconButton(
            tooltip: 'Profile & verification',
            icon: const Icon(Icons.verified_user),
            onPressed: session.busy
                ? null
                : () => context.go('/verification-status'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: session.busy ? null : session.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: session.busy
                ? null
                : () async {
                    await session.logout();
                    if (context.mounted && !session.authenticated) {
                      context.go(session.landingPath);
                    }
                  },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await session.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session.busy) const LinearProgressIndicator(),
            if (session.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    session.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            SwitchListTile(
              title: Text(session.online ? 'Online' : 'Offline'),
              subtitle: Text(
                'Verification: ${profile['verificationStatus'] ?? 'Unknown'}',
              ),
              value: session.online,
              onChanged: session.busy ? null : session.setOnline,
            ),
            ListTile(
              leading: const Icon(Icons.sensors),
              title: Text('Realtime: ${session.realtimeStatus}'),
              subtitle: Text(
                session.lastLocationSent == null
                    ? 'Location has not been sent yet.'
                    : 'Location accepted by server at ${session.lastLocationSent!.toLocal()}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Current location'),
              subtitle: Text(
                session.position == null
                    ? 'Locate your device to view GPS coordinates.'
                    : '${session.position!.latitude.toStringAsFixed(5)}, ${session.position!.longitude.toStringAsFixed(5)}',
              ),
              trailing: IconButton(
                onPressed: session.busy ? null : session.locate,
                icon: const Icon(Icons.gps_fixed),
              ),
            ),
            const Text(
              'Assigned vehicle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: Text(
                session.assignedVehicle?['plateNumber']?.toString() ??
                    'No vehicle assigned',
              ),
              subtitle: Text(
                '${session.assignedVehicle?['make'] ?? ''} ${session.assignedVehicle?['model'] ?? ''}',
              ),
            ),
            const Divider(),
            const Text(
              'Current trip',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (trip == null)
              const ListTile(title: Text('No active trip'))
            else ...[
              _rideTile(trip),
              if (next != null)
                ElevatedButton(
                  onPressed: session.busy ? null : () => _next(session, next),
                  child: Text(actionLabel[next]!),
                ),
              OutlinedButton(
                onPressed: session.busy
                    ? null
                    : () async {
                        await session.run(() async {
                          if (session.position == null) {
                            throw const ApiException(
                              'Locate your device before calculating the route.',
                            );
                          }
                          final target = trip['status'] == 'in_progress'
                              ? trip['destination']
                              : trip['pickup'];
                          final data = await session.api.request(
                            'POST',
                            '/maps/route',
                            body: {
                              'origin': {
                                'latitude': session.position!.latitude,
                                'longitude': session.position!.longitude,
                              },
                              'destination': target,
                              'mode': 'driving',
                              'avoidTolls': false,
                            },
                          );
                          if (mounted) {
                            setState(
                              () => _route = Map<String, dynamic>.from(
                                data as Map,
                              ),
                            );
                          }
                        });
                      },
                child: const Text('Calculate route to next stop'),
              ),
              if (_route != null)
                Text(
                  'Road distance: ${((_route!['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km · '
                  'Duration: ${((_route!['durationSeconds'] as num) / 60).ceil()} minutes',
                ),
            ],
            const Divider(),
            const Text(
              'Available rides',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (session.rides.isEmpty)
              const ListTile(title: Text('No available rides')),
            for (final ride in session.rides)
              Card(
                child: Column(
                  children: [
                    _rideTile(ride),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: session.busy
                              ? null
                              : () => session.decline(ride['id'] as String),
                          child: const Text('Decline'),
                        ),
                        ElevatedButton(
                          onPressed: session.busy
                              ? null
                              : () => session.accept(ride['id'] as String),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(),
            const Text(
              'Trip history & earnings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Trips: ${session.history?['totalTrips'] ?? 0} · Earnings: ₹${session.history?['totalEarnings'] ?? 0}',
            ),
            for (final ride in (session.history?['rides'] as List? ?? []))
              _rideTile(Map<String, dynamic>.from(ride as Map)),
            const Divider(),
            const Text(
              'Location search',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search Patna / Bihar',
              ),
            ),
            OutlinedButton(
              onPressed: session.busy
                  ? null
                  : () async {
                      await session.run(() async {
                        final data = await session.api.request(
                          'GET',
                          '/maps/search?query=${Uri.encodeQueryComponent(_search.text.trim())}',
                        );
                        if (mounted) {
                          setState(
                            () => _places = (data as List)
                                .map((p) => Map<String, dynamic>.from(p as Map))
                                .toList(),
                          );
                        }
                      });
                    },
              child: const Text('Search'),
            ),
            for (final place in _places)
              ListTile(
                title: Text(
                  place['description']?.toString() ??
                      place['name']?.toString() ??
                      place['address']?.toString() ??
                      'Location',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rideTile(Map<String, dynamic> ride) => ListTile(
    title: Text(
      '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['destinationAddress'] ?? 'Destination'}',
    ),
    subtitle: Text(
      '${ride['status']} · ${ride['sector'] ?? ''} · '
      '${ride['vehicleCategory'] ?? ''}\nRide ${ride['id']}',
    ),
    trailing: Text('₹${ride['finalFare'] ?? ride['fareEstimate'] ?? '—'}'),
    isThreeLine: true,
  );
}

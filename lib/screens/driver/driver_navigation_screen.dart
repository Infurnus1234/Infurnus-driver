import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/ride_pin_dialog.dart';
import '../../widgets/ride_customer_contact_card.dart';
import '../../widgets/operations.dart';
import '../../widgets/reference_components.dart';
import 'operations_dashboard.dart' show LogisticsUpfrontPaymentCard;

class DriverNavigationScreen extends StatelessWidget {
  const DriverNavigationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>(), trip = session.currentTrip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip navigation')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/driver/dashboard'),
            child: const Text('No active trip · Return to dashboard'),
          ),
        ),
      );
    }
    final status = trip['status'];
    final next = const {
      'driver_assigned': 'driver_arriving',
      'driver_arriving': 'driver_arrived',
      'in_progress': 'completed',
    }[status];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const TripMap(
            key: ValueKey('driver-full-screen-map'),
            fullScreen: true,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 64,
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to dashboard',
                      onPressed: () => context.go('/driver/dashboard'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Expanded(child: Center(child: InfurnusBrand())),
                    IconButton(
                      tooltip: 'Safety',
                      onPressed: () => context.push('/safety'),
                      icon: const Icon(Icons.shield_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .58,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const RideCustomerContactCard(compact: true),
                        const Divider(height: 27),
                        if (trip['sector'] == 'logistics')
                          LogisticsUpfrontPaymentCard(
                            trip: trip,
                            session: session,
                          ),
                        if (status == 'driver_arrived')
                          RidePinDialog(
                            key: ValueKey(trip['id']),
                            session: session,
                            embedded: true,
                          )
                        else if (status != 'in_progress') ...[
                          const Row(
                            children: [
                              Icon(Icons.lock, color: Color(0xFF16233D)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Enter PIN to Start Ride',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              for (var i = 0; i < 4; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFE2E5EC),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Arrive at pickup to verify the passenger’s PIN.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (next != null)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00B313),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: session.busy
                                ? null
                                : () async {
                                    if (next == 'completed' &&
                                        !await confirmOperation(
                                          context,
                                          'Complete this trip?',
                                          'Confirm that the passenger or shipment has reached the destination.',
                                        )) {
                                      return;
                                    }
                                    if (await session.transition(next) &&
                                        next == 'completed' &&
                                        context.mounted) {
                                      context.go('/driver/dashboard');
                                    }
                                  },
                            child: Text(
                              session.busy
                                  ? 'Updating trip…'
                                  : const {
                                      'driver_arriving': 'Start toward pickup',
                                      'driver_arrived': 'Arrived at pickup',
                                      'completed': 'Complete Ride',
                                    }[next]!,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (session.error != null && status != 'driver_arrived')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              session.error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/safety'),
                              child: const Text('Safety'),
                            ),
                            TextButton(
                              onPressed: () => context.push('/support-tickets'),
                              child: const Text('Support'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

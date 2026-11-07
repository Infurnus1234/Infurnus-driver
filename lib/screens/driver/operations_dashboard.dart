import '../../services/ride_request_presentation.dart' show driverDropAddress;

import 'dart:async';

import 'driver_home_screen.dart';
import '../../widgets/incoming_ride_request_card.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';
import '../../widgets/reference_components.dart';

class OperationsDashboard extends StatelessWidget {
  const OperationsDashboard({super.key});
  @override
  Widget build(BuildContext context) => const DriverHomeScreen();
}

class RideDetails extends StatelessWidget {
  final Map ride;
  const RideDetails({super.key, required this.ride});
  @override
  Widget build(BuildContext context) {
    final fareInfo = (ride['rideInformation'] as Map?)?['fare'] as Map?;
    final fare =
        fareInfo?['amount'] ?? ride['finalFare'] ?? ride['fareEstimate'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ride['bookingId'] != null)
          SelectableText("Booking ID: ${ride['bookingId']}"),
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
            ride['sector'] == 'logistics'
                ? driverDropAddress(ride) ??
                      'Available after passenger PIN verification'
                : ride['pinVerified'] == true &&
                      ['in_progress', 'completed'].contains(ride['status'])
                ? ride['destinationAddress']?.toString() ?? 'Not provided'
                : ride['sector'] == 'service'
                ? 'Available after customer PIN verification'
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
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                Text(
                  fareInfo?['authority'] == 'final' || ride['finalFare'] != null
                      ? 'Final fare'
                      : ride['sector'] == 'service'
                      ? 'Fixed service fare'
                      : 'Estimated fare',
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
        if (ride['sector'] == 'rental' || ride['sector'] == 'premium')
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ride['sector'] == 'rental' ? 'Rental' : 'Premium'),
            subtitle: Text(
              [
                ride['vehicleCategory'] ?? 'Vehicle',
                if (ride['rentalDetails'] is Map &&
                    (ride['rentalDetails'] as Map)['hours'] != null)
                  "${(ride['rentalDetails'] as Map)['hours']} hours",
              ].join(' · '),
            ),
          ),
        if (ride['sector'] == 'service' && ride['serviceDetails'] is Map)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Service details'),
            subtitle: Text(
              [
                for (final key in ['emergencyLevel', 'description', 'notes'])
                  if ((ride['serviceDetails'] as Map)[key] != null)
                    '${(ride['serviceDetails'] as Map)[key]}',
              ].join(' · '),
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
              subtitle: SelectableText(
                ride['bookingId'] == null
                    ? 'Booking ID unavailable'
                    : 'Booking ID: ${ride['bookingId']}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class RideOfferCard extends StatefulWidget {
  final Map<String, dynamic> ride;
  final DateTime Function()? clock;
  const RideOfferCard({super.key, required this.ride, this.clock});
  @override
  State<RideOfferCard> createState() => _RideOfferCardState();
}

class _RideOfferCardState extends State<RideOfferCard> {
  Timer? _timer;
  DateTime _localAnchor = DateTime.now();
  DateTime? _serverAnchor;
  Map<String, dynamic> get ride => widget.ride;
  void _synchronize() {
    _serverAnchor = DateTime.tryParse(ride['serverTime']?.toString() ?? '');
    _localAnchor =
        DateTime.tryParse(ride['_receivedAt']?.toString() ?? '') ??
        widget.clock?.call() ??
        DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    _synchronize();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RideOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride['serverTime'] != ride['serverTime'] ||
        oldWidget.ride['id'] != ride['id']) {
      _synchronize();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final expiry = DateTime.tryParse(
      ride['dispatchExpiresAt']?.toString() ?? '',
    );
    final localNow = widget.clock?.call() ?? DateTime.now();
    final now =
        _serverAnchor?.add(localNow.difference(_localAnchor)) ?? localNow;
    final remaining = expiry?.difference(now).inMilliseconds;
    return IncomingRideRequestCard(
      ride: ride,
      remaining: Duration(milliseconds: remaining ?? 0),
      busy: session.busy,
      reject: () => session.decline(ride['id'] as String),
      accept: () async {
        if (await session.accept(ride['id'] as String) && context.mounted) {
          context.go('/driver/active-trip');
        }
      },
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
            for (final ride in session.rides)
              RideOfferCard(key: ValueKey(ride['id']), ride: ride),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logistics payment banner shown to driver while waiting for customer payment
// ─────────────────────────────────────────────────────────────────────────────
class LogisticsUpfrontPaymentCard extends StatelessWidget {
  final Map trip;
  final DriverSession session;
  const LogisticsUpfrontPaymentCard({
    super.key,
    required this.trip,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    if (trip['sector'] != 'logistics') return const SizedBox.shrink();
    final payment = trip['logisticsPayment'] as Map?;
    num? rupees(String paise, String legacy) {
      final value = payment?[paise];
      return value is num ? value / 100 : payment?[legacy] as num?;
    }

    final fare = rupees('totalPaise', 'totalFare');
    final upfrontAmount = rupees('upfrontPaise', 'upfrontAmount');
    final remainingAmount = rupees('finalPaise', 'remainingAmount');
    String display(num? amount) =>
        amount == null ? 'Unavailable' : inrRupees(amount);
    final status =
        trip['upfrontPaymentStatus']?.toString().toUpperCase() ?? 'PENDING';
    final method =
        trip['upfrontPaymentMethod']?.toString().toLowerCase() ?? 'online';
    final isVerified = status == 'PAID_VERIFIED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Logistics 40% Upfront Payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              StatusPill(status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total Fare: ${display(fare)}',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            '40% Payable Upfront: ${display(upfrontAmount)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            '60% Remaining (Post-Delivery): ${display(remainingAmount)}',
            style: const TextStyle(color: Ops.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment Method: ${method.toUpperCase()}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (!isVerified) ...[
            if (method == 'cash')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Ops.actionPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: session.busy
                    ? null
                    : () => session.confirmLogisticsUpfrontCash(
                        trip['id'].toString(),
                      ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Confirm 40% Cash Received'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Ops.actionPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: session.busy
                    ? null
                    : () => session.payLogisticsUpfrontOnline(
                        trip['id'].toString(),
                      ),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Refresh online payment status'),
              ),
            const SizedBox(height: 6),
            const Text(
              'Ride start is blocked until 40% upfront payment is verified.',
              style: TextStyle(color: Ops.error, fontSize: 11),
            ),
          ] else ...[
            const Text(
              '40% upfront payment verified successfully. You can now verify PIN and start ride.',
              style: TextStyle(
                color: Ops.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

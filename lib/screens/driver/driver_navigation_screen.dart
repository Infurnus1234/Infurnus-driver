import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/trip_map.dart';
import '../../widgets/ride_pin_dialog.dart';
import '../../widgets/ride_customer_contact_card.dart';
import '../../widgets/operations.dart';
import '../../widgets/reference_components.dart';
import 'operations_dashboard.dart'
    show LogisticsUpfrontPaymentCard, RideDetails;

class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({super.key});

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen>
    with SingleTickerProviderStateMixin {
  static const _half = .5;
  static const _full = .86;
  late final _extent = AnimationController(vsync: this);

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  void _resize(double target) {
    if (target < _half) FocusManager.instance.primaryFocus?.unfocus();
    _extent.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _dashboard() {
    if (mounted) context.go('/driver/dashboard');
  }

  void _snap(double minimum, double velocity) {
    final size = math.max(minimum, _extent.value);
    final stops = [minimum, _half, _full];
    final target = switch (velocity) {
      < -360 => stops.firstWhere(
        (stop) => stop > size + .015,
        orElse: () => _full,
      ),
      > 360 => stops.lastWhere(
        (stop) => stop < size - .015,
        orElse: () => minimum,
      ),
      _ => stops.reduce((a, b) => (a - size).abs() < (b - size).abs() ? a : b),
    };
    _resize(target);
  }

  @override
  Widget build(BuildContext context) {
    final rideId = context.select((DriverSession s) => s.currentTrip?['id']);
    if (rideId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip navigation')),
        body: Center(
          child: TextButton(
            onPressed: _dashboard,
            child: const Text('No active trip · Return to dashboard'),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dashboard();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final safeBottom = MediaQuery.paddingOf(context).bottom;
            final summaryHeight =
                MediaQuery.textScalerOf(context).scale(54) + 49;
            final minimum = math
                .max(.18, (summaryHeight + safeBottom) / height)
                .clamp(.18, .46)
                .toDouble();
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _extent,
                  builder: (context, _) => TripMap(
                    key: const ValueKey('driver-full-screen-map'),
                    fullScreen: true,
                    bottomInset: math.max(_extent.value, minimum) * height,
                    onMapTap: () => _resize(minimum),
                  ),
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
                            onPressed: _dashboard,
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
                  child: AnimatedBuilder(
                    animation: _extent,
                    child: _RidePanelDetails(onCompleted: _dashboard),
                    builder: (context, details) {
                      final size = math.max(minimum, _extent.value);
                      final collapsed = size <= minimum + .001;
                      return SizedBox(
                        key: const ValueKey('active-ride-panel'),
                        height: size * height,
                        child: Material(
                          color: Colors.white,
                          elevation: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  excludeFromSemantics: true,
                                  onVerticalDragStart: (_) => _extent.stop(),
                                  onVerticalDragUpdate: (event) =>
                                      _extent.value =
                                          (math.max(minimum, _extent.value) -
                                                  event.delta.dy / height)
                                              .clamp(minimum, _full)
                                              .toDouble(),
                                  onVerticalDragEnd: (event) => _snap(
                                    minimum,
                                    event.primaryVelocity ?? 0,
                                  ),
                                  onVerticalDragCancel: () => _snap(minimum, 0),
                                  child: SizedBox(
                                    height: math.max(
                                      0,
                                      minimum * height - safeBottom,
                                    ),
                                    child: _RidePanelHeader(
                                      onTap: () {
                                        final size = _extent.value;
                                        _resize(
                                          size < _half - .02
                                              ? _half
                                              : size < _full - .02
                                              ? _full
                                              : minimum,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring: collapsed,
                                    child: ExcludeSemantics(
                                      excluding: collapsed,
                                      child: ExcludeFocus(
                                        excluding: collapsed,
                                        child: details!,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RidePanelHeader extends StatelessWidget {
  const _RidePanelHeader({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bookingId, rideStatus, customer) = context.select(
      (DriverSession s) => (
        s.currentTrip?['bookingId'],
        s.currentTrip?['status'],
        s.activeCustomerContact?.name,
      ),
    );
    final status =
        const {
          'driver_assigned': 'Assigned',
          'driver_arriving': 'Heading to pickup',
          'driver_arrived': 'At pickup',
          'in_progress': 'In progress',
        }[rideStatus] ??
        'Ongoing ride';
    return LayoutBuilder(
      builder: (context, bounds) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: 'Resize ride details',
              button: true,
              onTap: onTap,
              excludeSemantics: true,
              child: InkWell(
                key: const ValueKey('ride-details-handle'),
                onTap: onTap,
                child: SizedBox(
                  height: math.min(44, bounds.maxHeight / 2),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7C1D0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer == null || customer.isEmpty
                            ? 'Customer'
                            : customer,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (bookingId != null) 'Booking #$bookingId',
                          status,
                        ].join(' · '),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RidePanelDetails extends StatelessWidget {
  const _RidePanelDetails({required this.onCompleted});
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final (id, status, sector, busy, error) = context.select(
      (DriverSession s) => (
        s.currentTrip?['id'],
        s.currentTrip?['status'],
        s.currentTrip?['sector'],
        s.busy,
        s.error,
      ),
    );
    final session = context.read<DriverSession>();
    final next = const {
      'driver_assigned': 'driver_arriving',
      'driver_arriving': 'driver_arrived',
      'in_progress': 'completed',
    }[status];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RideCustomerContactCard(compact: true),
            const Divider(height: 27),
            if (sector == 'logistics') const _ActiveRidePayment(),
            if (status == 'driver_arrived')
              RidePinDialog(key: ValueKey(id), session: session, embedded: true)
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
                          border: Border.all(color: const Color(0xFFE2E5EC)),
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
                style: TextStyle(fontSize: 12, color: Colors.black54),
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
                onPressed: busy
                    ? null
                    : () async {
                        String? endPin;
                        if (next == 'completed') {
                          if (sector == 'logistics') {
                            endPin = await _promptDeliveryOtp(context);
                            if (endPin == null) return;
                          }
                          if (!context.mounted) return;
                          if (!await confirmOperation(
                            context,
                            'Complete this trip?',
                            'Confirm that the passenger or shipment has reached the destination.',
                          )) {
                            return;
                          }
                        }
                        if (await session.transition(next, endPin: endPin) &&
                            next == 'completed') {
                          onCompleted();
                        }
                      },
                child: Text(
                  busy
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
            const _ActiveRideFacts(),
            if (error != null && status != 'driver_arrived')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.center,
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
    );
  }
}

class _ActiveRidePayment extends StatelessWidget {
  const _ActiveRidePayment();

  @override
  Widget build(BuildContext context) =>
      Selector<DriverSession, Map<String, dynamic>>(
        selector: (_, s) => {
          for (final key in [
            'id',
            'sector',
            'logisticsPayment',
            'upfrontPaymentStatus',
            'upfrontPaymentMethod',
          ])
            key: s.currentTrip?[key],
          'paymentRefreshing': s.paymentRefreshing,
          'paymentRefreshError': s.paymentRefreshError,
          'busy': s.busy,
        },
        builder: (context, trip, _) => LogisticsUpfrontPaymentCard(
          trip: trip,
          session: context.read<DriverSession>(),
        ),
      );
}

class _ActiveRideFacts extends StatelessWidget {
  const _ActiveRideFacts();

  @override
  Widget build(BuildContext context) =>
      Selector<DriverSession, Map<String, dynamic>>(
        selector: (_, s) => {
          for (final key in [
            'bookingId',
            'sector',
            'status',
            'pinVerified',
            'pickupAddress',
            'destinationAddress',
            'destinationDistrict',
            'fareEstimate',
            'finalFare',
            'vehicleCategory',
            'rentalDetails',
            'serviceDetails',
          ])
            key: s.currentTrip?[key],
          'rideInformation': {
            'fare': s.currentTrip?['rideInformation']?['fare'],
          },
        },
        builder: (_, ride, _) => RideDetails(ride: ride),
      );
}

Future<String?> _promptDeliveryOtp(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.local_shipping, color: Color(0xFF00B313)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Delivery PIN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask the customer for their 4-digit Delivery PIN to confirm delivery and complete the trip.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00B313),
          ),
          onPressed: () {
            final pin = controller.text.trim();
            if (pin.length == 4) {
              Navigator.of(dialogContext).pop(pin);
            }
          },
          child: const Text('Verify & Complete'),
        ),
      ],
    ),
  );
}

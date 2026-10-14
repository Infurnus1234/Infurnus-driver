import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/driver_session.dart';
import '../../services/api_service.dart';
import '../../core/theme.dart';
import '../../widgets/driver_bottom_nav.dart';

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
          title: Text('Customer Pickup PIN', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: '4-digit PIN provided by customer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: InfurnusTheme.buttonBlack,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Verify & Start'),
            ),
          ],
        ),
      );
      Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      );
      if (pin == null) return;
    }
    await session.transition(status, pin: pin);
    if (mounted) setState(() => _route = null);
  }

  void _showModeSwitchModal(DriverSession session) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        final currentMode = session.api.providerMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Switch Mode',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: InfurnusTheme.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _modeCard(
                  title: 'Driver Mode',
                  subtitle: 'Drive and earn rides',
                  icon: Icons.directions_car,
                  selected: currentMode == 'driver',
                  onTap: () async {
                    Navigator.pop(context);
                    if (currentMode != 'driver') {
                      final ok = await session.switchMode('driver');
                      if (context.mounted && ok) context.go(session.landingPath);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _modeCard(
                  title: 'Fleet Owner Mode',
                  subtitle: 'Manage your fleet, vehicles and drivers',
                  icon: Icons.business,
                  selected: currentMode == 'fleet_owner',
                  onTap: () async {
                    Navigator.pop(context);
                    if (currentMode != 'fleet_owner') {
                      final ok = await session.switchMode('fleet_owner');
                      if (context.mounted && ok) context.go(session.landingPath);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? InfurnusTheme.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? InfurnusTheme.primaryGreen : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: selected ? Colors.white : InfurnusTheme.textDark, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: InfurnusTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: InfurnusTheme.primaryGreen, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    if (!session.authenticated || (!session.busy && !session.dashboardAllowed)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(session.landingPath);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final trip = session.currentTrip;
    final history = session.history ?? {};
    final driverName = session.account?['firstName'] ?? session.profile?['name'] ?? 'Partner';

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
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: InfurnusTheme.primaryGreen,
              child: Text(
                driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day,',
                  style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted),
                ),
                Text(
                  '$driverName 👋',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: InfurnusTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: InfurnusTheme.textDark),
            onPressed: () => context.push('/notifications'),
          ),
          if (session.api.hasFleetRole)
            IconButton(
              tooltip: 'Switch Mode',
              icon: const Icon(Icons.swap_horiz, color: InfurnusTheme.textDark),
              onPressed: session.busy ? null : () => _showModeSwitchModal(session),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: session.busy ? null : session.refresh,
            icon: const Icon(Icons.refresh, color: InfurnusTheme.textDark),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: InfurnusTheme.textDark),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (session.busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(color: InfurnusTheme.primaryGreen),
              ),
            if (session.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: InfurnusTheme.dangerRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.error!,
                        style: GoogleFonts.inter(color: InfurnusTheme.dangerRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Reference Screens 11 & 12: Online / Offline Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: session.online ? InfurnusTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: session.online ? InfurnusTheme.primaryGreen : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: session.online
                        ? InfurnusTheme.primaryGreen.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: session.online
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          session.online ? Icons.check_circle : Icons.power_settings_new,
                          color: session.online ? Colors.white : InfurnusTheme.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.online ? "You're Online" : "You're Offline",
                            style: GoogleFonts.inter(
                              color: session.online ? Colors.white : InfurnusTheme.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            session.online
                                ? "Ready to accept incoming rides"
                                : "Go online to receive new ride requests",
                            style: GoogleFonts.inter(
                              color: session.online ? Colors.white70 : InfurnusTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: session.online,
                    activeColor: Colors.white,
                    activeTrackColor: InfurnusTheme.greenDark,
                    inactiveThumbColor: Colors.grey,
                    onChanged: session.busy ? null : session.setOnline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Map & Location Simulation Area (Screens 11 & 12)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: session.online ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Map grid pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                        ),
                        itemCount: 24,
                        itemBuilder: (_, _) => Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26, width: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Driver Marker & Pulse
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: session.online
                              ? InfurnusTheme.primaryGreen
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (session.online ? InfurnusTheme.primaryGreen : Colors.black)
                                  .withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Text(
                          session.position == null
                              ? 'Locating device…'
                              : '${session.position!.latitude.toStringAsFixed(4)}, ${session.position!.longitude.toStringAsFixed(4)}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  // Locate Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'locateBtn',
                      backgroundColor: Colors.white,
                      foregroundColor: InfurnusTheme.textDark,
                      onPressed: session.busy ? null : session.locate,
                      child: const Icon(Icons.my_location, size: 18),
                    ),
                  ),

                  // Bottom action within map
                  Positioned(
                    bottom: 12,
                    child: session.online
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: InfurnusTheme.dangerRed,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: session.busy ? null : () => session.setOnline(false),
                            icon: const Icon(Icons.power_settings_new, size: 16),
                            label: const Text('Go Offline'),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: session.busy ? null : () => session.setOnline(true),
                            icon: const Icon(Icons.bolt, size: 16),
                            label: const Text('Go Online'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Today's Earnings Card (Screens 11 & 12)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Earnings",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: InfurnusTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => context.go('/driver/earnings'),
                        child: Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: InfurnusTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${history['totalEarnings'] ?? '1,280'}',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: InfurnusTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricCol('${history['totalTrips'] ?? '8'}', 'Trips'),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      _metricCol('126 km', 'Distance'),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      _metricCol(session.realtimeStatus, 'Status'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Incoming Ride Requests (Screen 13)
            if (session.rides.isNotEmpty) ...[
              Text(
                'Incoming Ride Requests (${session.rides.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: InfurnusTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              for (final ride in session.rides)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: InfurnusTheme.primaryGreen.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: InfurnusTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '2.4 km away • 6 min',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: InfurnusTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '00:18',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: InfurnusTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: InfurnusTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride['pickupAddress'] ?? 'Boring Road, Patna',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: InfurnusTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: InfurnusTheme.dangerRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride['destinationAddress'] ?? 'Patna Junction',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: InfurnusTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Fare',
                            style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textMuted),
                          ),
                          Text(
                            '₹${ride['finalFare'] ?? ride['fareEstimate'] ?? '286'}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: InfurnusTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: InfurnusTheme.dangerRed,
                                side: const BorderSide(color: InfurnusTheme.dangerRed),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: session.busy
                                  ? null
                                  : () => session.decline(ride['id'] as String),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: InfurnusTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: session.busy
                                  ? null
                                  : () => session.accept(ride['id'] as String),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],

            // Active Trip Banner (Screens 14 & 15)
            if (trip != null) ...[
              Text(
                'Active Trip',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: InfurnusTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _rideTile(trip),
                    const SizedBox(height: 12),
                    if (next != null)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InfurnusTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: session.busy ? null : () => _next(session, next),
                        child: Text(actionLabel[next]!),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InfurnusTheme.buttonBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                                    () => _route = Map<String, dynamic>.from(data as Map),
                                  );
                                }
                              });
                            },
                      child: const Text('Calculate Route to Next Stop'),
                    ),
                    if (_route != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Road distance: ${((_route!['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km · Duration: ${((_route!['durationSeconds'] as num) / 60).ceil()} mins',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: InfurnusTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Assigned Vehicle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: InfurnusTheme.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: InfurnusTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.assignedVehicle?['plateNumber']?.toString() ??
                              'No vehicle assigned',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: InfurnusTheme.textDark,
                          ),
                        ),
                        Text(
                          '${session.assignedVehicle?['make'] ?? ''} ${session.assignedVehicle?['model'] ?? ''}'
                                  .trim()
                                  .isEmpty
                              ? 'Assigned to your driver profile'
                              : '${session.assignedVehicle?['make']} ${session.assignedVehicle?['model']}',
                          style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location Search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Search',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: InfurnusTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search Patna / Bihar',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InfurnusTheme.buttonBlack,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(80, 48),
                        ),
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
                    ],
                  ),
                  if (_places.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final place in _places)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined, color: InfurnusTheme.primaryGreen),
                        title: Text(
                          place['description']?.toString() ??
                              place['name']?.toString() ??
                              place['address']?.toString() ??
                              'Location',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
    );
  }

  Widget _metricCol(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: InfurnusTheme.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted),
        ),
      ],
    );
  }

  Widget _rideTile(Map<String, dynamic> ride) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ride #${ride['id'] ?? ''}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: InfurnusTheme.textDark,
            ),
          ),
          Text(
            '₹${ride['finalFare'] ?? ride['fareEstimate'] ?? '—'}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: InfurnusTheme.primaryGreen,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Pickup: ${ride['pickupAddress'] ?? 'Pickup'}',
        style: GoogleFonts.inter(fontSize: 13, color: InfurnusTheme.textDark),
      ),
      Text(
        'Dropoff: ${ride['destinationAddress'] ?? 'Destination'}',
        style: GoogleFonts.inter(fontSize: 13, color: InfurnusTheme.textDark),
      ),
      const SizedBox(height: 4),
      Text(
        'Status: ${ride['status']} • Category: ${ride['vehicleCategory'] ?? ''}',
        style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted),
      ),
    ],
  );
}

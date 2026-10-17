import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/driver_session.dart';
import '../../services/api_service.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../widgets/waiting_timer_widget.dart';
import '../../widgets/dispatch_countdown_widget.dart';
import '../../core/theme.dart';

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
    if (session.isPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action simulated in test preview mode.')),
      );
      await session.transition(status);
      return;
    }
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
            FilledButton(
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    if (!session.authenticated && !(!kReleaseMode && session.isPreview)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(session.landingPath);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final trip = session.currentTrip;
    final profile = session.profile ?? {};
    final driverName = profile['firstName']?.toString() ?? session.account?['firstName']?.toString() ?? 'Driver';

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: InfurnusTheme.primaryGreen.withValues(alpha: 0.15),
              child: Text(
                driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: InfurnusTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good Morning',
                  style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted),
                ),
                Text(
                  driverName,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined, color: InfurnusTheme.textDark),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: 'Owned vehicles & provider profile',
            icon: const Icon(Icons.local_shipping_outlined, color: InfurnusTheme.textDark),
            onPressed: session.busy ? null : () => context.go('/provider-assets'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: InfurnusTheme.textDark),
            onPressed: session.busy ? null : session.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await session.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session.isPreview)
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'TEST PREVIEW — NOT AUTHENTICATED',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Online / Offline Toggle Banner (Matching UI Mockup 11 & 12)
            Container(
              decoration: BoxDecoration(
                color: session.online ? InfurnusTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: session.online ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (session.online ? InfurnusTheme.primaryGreen : Colors.black).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.online ? "You're Online" : "You're Offline",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: session.online ? Colors.white : InfurnusTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.online
                              ? 'Searching for rides nearby...'
                              : 'Go online to receive new ride requests',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: session.online ? Colors.white70 : InfurnusTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: session.online,
                    activeColor: Colors.white,
                    activeTrackColor: InfurnusTheme.greenDark,
                    onChanged: session.busy ? null : (v) => session.setOnline(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Earnings Summary Card (Matching UI Mockup 11)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Earnings",
                    style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${session.history?['totalEarnings'] ?? 1280}',
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${session.history?['totalTrips'] ?? 8}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text('Trips', style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted)),
                        ],
                      ),
                      Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          Text(
                            '126 km',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text('Distance', style: GoogleFonts.inter(fontSize: 11, color: InfurnusTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Current Trip & Navigation Map Banner (Matching UI Mockup 13, 14, 15)
            if (trip != null) ...[
              Text(
                'Current trip & navigation',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.primaryGreen.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_rounded, size: 44, color: InfurnusTheme.primaryGreen),
                              const SizedBox(height: 6),
                              Text(
                                trip['status'] == 'in_progress' ? 'LIVE DESTINATION NAVIGATION' : 'LIVE PICKUP NAVIGATION',
                                style: GoogleFonts.inter(
                                  color: InfurnusTheme.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                session.position == null
                                    ? 'GPS Locating...'
                                    : 'GPS: ${session.position!.latitude.toStringAsFixed(4)}, ${session.position!.longitude.toStringAsFixed(4)}',
                                style: GoogleFonts.inter(color: InfurnusTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    trip['status'] == 'in_progress' ? Icons.location_on : Icons.navigation,
                                    color: trip['status'] == 'in_progress' ? Colors.red : Colors.blue,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip['status'] == 'in_progress' ? 'Drop Off' : 'Pickup',
                                          style: GoogleFonts.inter(color: InfurnusTheme.textMuted, fontSize: 11),
                                        ),
                                        Text(
                                          trip['status'] == 'in_progress'
                                              ? (trip['destinationAddress']?.toString() ?? 'Destination')
                                              : (trip['pickupAddress']?.toString() ?? 'Pickup'),
                                          style: GoogleFonts.inter(
                                            color: InfurnusTheme.textDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _rideTile(trip),
                          if (trip['status'] == 'driver_arrived') ...[
                            const SizedBox(height: 10),
                            WaitingTimerWidget(
                              arrivalTime: DateTime.tryParse(trip['updatedAt']?.toString() ?? '') ?? DateTime.now(),
                            ),
                          ],
                          if (next != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: InfurnusTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: session.busy ? null : () => _next(session, next),
                              child: Text(
                                actionLabel[next]!,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Available Rides List (Matching UI Mockup 13)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available rides',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: InfurnusTheme.textDark),
                ),
                if (session.rides.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: InfurnusTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${session.rides.length} new',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: InfurnusTheme.primaryGreen),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (session.rides.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text(
                  'No ride requests available right now. Keep online enabled.',
                  style: GoogleFonts.inter(color: InfurnusTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final ride in session.rides)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _rideTile(ride),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DispatchCountdownWidget(
                        expiresAt: DateTime.tryParse(ride['dispatchExpiresAt']?.toString() ?? '') ?? DateTime.now().add(const Duration(seconds: 15)),
                        onExpired: () => session.decline(ride['id'] as String),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: session.busy ? null : () => session.decline(ride['id'] as String),
                              child: Text('Decline', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: InfurnusTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: session.busy ? null : () => session.accept(ride['id'] as String),
                              child: Text('Accept', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
    );
  }

  Widget _rideTile(Map<String, dynamic> ride) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    title: Text(
      '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['destinationAddress'] ?? 'Destination'}',
      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: InfurnusTheme.textDark),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${ride['status']} · ${ride['sector'] ?? ''} · ${ride['vehicleCategory'] ?? ''}\nRide ${ride['id']}',
        style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textMuted),
      ),
    ),
    trailing: Text(
      '₹${ride['finalFare'] ?? ride['fareEstimate'] ?? '—'}',
      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: InfurnusTheme.primaryGreen),
    ),
    isThreeLine: true,
  );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../services/ride_request_presentation.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../widgets/operations.dart' show OpsError;
import '../../widgets/reference_components.dart';
import '../../widgets/incoming_ride_request_card.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});
  Future<void> _alerts(BuildContext context) async {
    final bridge = RideRequestBridge();
    final status = await bridge.status();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ride request alerts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                status?['overlay'] == true
                    ? 'Requests can appear over other apps.'
                    : 'Allow Display over other apps to see ride requests while using another app. Without it, incoming requests use notifications.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await bridge.requestOverlayPermission();
                },
                child: const Text('Display over other apps'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await bridge.requestNotificationPermission();
                },
                child: Text(
                  status?['notifications'] == true
                      ? 'Request sound and vibration settings'
                      : 'Allow request notifications',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final account = session.account ?? session.profile ?? {};
    final name = [
      account['firstName'],
      account['lastName'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' ');
    final photo =
        (session.driverPhotoUrl ??
                account['photoUrl'] ??
                account['avatarUrl'] ??
                session.profile?['photoUrl'] ??
                session.profile?['avatarUrl'])
            ?.toString();
    final summary = session.todaySummary;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const InfurnusBrand(),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible:
                  (session.account?['unreadNotificationCount'] as num? ?? 0) >
                  0,
              smallSize: 7,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(child: InfurnusBrand()),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Driver Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/driver/dashboard');
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_taxi_outlined),
                title: const Text('Ride requests'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/driver/ride-requests');
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Ride request alerts'),
                onTap: () {
                  Navigator.pop(context);
                  _alerts(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile');
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          await session.refresh();
        },
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, bounds.maxHeight - 32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.error != null)
                    OpsError(
                      "We couldn't load this information. Please try again.",
                      retry: () => session.refresh(),
                    ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFE8ECEF),
                        backgroundImage: photo == null
                            ? null
                            : NetworkImage(photo),
                        onBackgroundImageError: photo == null
                            ? null
                            : (_, _) {},
                        child: photo == null
                            ? const Icon(
                                Icons.person,
                                size: 34,
                                color: Color(0xFF586678),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Driver Mode' : name,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              session.publicId == null
                                  ? 'Driver Mode'
                                  : 'Driver · ID: ${session.publicId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          color: session.online
                              ? requestGreen
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Text(
                              session.online ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: session.online
                                    ? Colors.white
                                    : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(
                              width: 54,
                              height: 39,
                              child: FittedBox(
                                child: Switch(
                                  value: session.online,
                                  onChanged: session.busy
                                      ? null
                                      : session.setOnline,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: requestGreen,
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: const Color(0xFFBCC2CB),
                                  trackOutlineColor:
                                      const WidgetStatePropertyAll(
                                        Colors.transparent,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEBEDF2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 9,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Today’s Ride Summary',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 15),
                                  SizedBox(width: 6),
                                  Text(
                                    'Today',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, c) {
                            final width = (c.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _Stat(
                                  width: width,
                                  label: 'Total Requests',
                                  value: summary?['totalRequests'],
                                  icon: Icons.layers,
                                  color: const Color(0xFFE9F3FF),
                                  accent: const Color(0xFF1678E8),
                                ),
                                _Stat(
                                  width: width,
                                  label: 'Accepted',
                                  value: summary?['accepted'],
                                  icon: Icons.check_circle,
                                  color: const Color(0xFFE8F8ED),
                                  accent: const Color(0xFF00A62A),
                                ),
                                _Stat(
                                  width: width,
                                  label: 'Rejected',
                                  value: summary?['rejected'],
                                  icon: Icons.cancel,
                                  color: const Color(0xFFFFEBED),
                                  accent: const Color(0xFFFA5160),
                                ),
                                _Stat(
                                  width: width,
                                  label: 'Total Rides',
                                  value: summary?['totalRides'],
                                  icon: Icons.local_taxi,
                                  color: const Color(0xFFF1EAFE),
                                  accent: const Color(0xFF853BE9),
                                ),
                              ],
                            );
                          },
                        ),
                        if (session.todaySummaryError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              session.todaySummaryError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      width: 260,
                      height: 70,
                      child: CustomPaint(painter: _WaitingCar()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.online ? 'You are Online' : 'You are Offline',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    session.online
                        ? session.locationWarning != null
                              ? 'Online preference saved. Check location to receive requests.'
                              : session.realtimeStatus == 'Connected'
                              ? 'Waiting for ride requests…'
                              : 'Online preference saved. Reconnecting to live requests…'
                        : 'Go online to receive ride requests.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final double width;
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color, accent;
  const _Stat({
    required this.width,
    required this.label,
    this.value,
    required this.icon,
    required this.color,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 114 + (MediaQuery.textScalerOf(context).scale(42) - 42),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: accent.withValues(alpha: .09)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 27),
        const Spacer(),
        Text(
          value == null ? '—' : '$value',
          style: const TextStyle(
            fontSize: 29,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _WaitingCar extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 260, s.height / 115);
    final pale = Paint()..color = const Color(0xFFECEFF6);
    for (var i = 0; i < 7; i++) {
      final x = 20 + i * 32.0, h = 25 + (i % 3) * 20.0;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 80 - h, 24, h),
          const Radius.circular(3),
        ),
        pale,
      );
    }
    final body = Paint()..color = const Color(0xFFCDD4E0),
        outline = Paint()
          ..color = const Color(0xFF8794A9)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(80, 72)
      ..lineTo(92, 44)
      ..quadraticBezierTo(130, 33, 168, 44)
      ..lineTo(180, 72)
      ..quadraticBezierTo(190, 77, 188, 96)
      ..lineTo(72, 96)
      ..quadraticBezierTo(70, 78, 80, 72);
    c.drawPath(path, body);
    c.drawPath(path, outline);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(94, 46, 73, 23),
        const Radius.circular(7),
      ),
      Paint()..color = Colors.white,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(79, 93, 16, 15),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF8794A9),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(165, 93, 16, 15),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF8794A9),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(82, 77, 23, 8),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(155, 77, 23, 8),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class OngoingRideCard extends StatelessWidget {
  final String? bookingId;
  final VoidCallback onTap;

  const OngoingRideCard({super.key, this.bookingId, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF0FAF2),
    child: ListTile(
      onTap: onTap,
      leading: const Icon(Icons.route_outlined, color: Color(0xFF087A32)),
      title: Text(
        bookingId == null
            ? 'Ongoing ride'
            : 'Ongoing ride · Booking #$bookingId',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: const Text('Return to your active ride'),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

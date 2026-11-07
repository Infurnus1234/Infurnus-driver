import 'package:flutter/material.dart';

import '../services/ride_request_presentation.dart';

const requestGreen = Color(0xFF00B313), requestNavy = Color(0xFF16233D);

class IncomingRideRequestCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final Duration remaining;
  final bool busy;
  final VoidCallback? accept, reject, close;
  const IncomingRideRequestCard({
    super.key,
    required this.ride,
    required this.remaining,
    this.busy = false,
    this.accept,
    this.reject,
    this.close,
  });
  @override
  Widget build(BuildContext context) {
    final details = nativeOffer(ride), expired = remaining <= Duration.zero;
    final hours = ride['rentalDetails'] is Map
        ? ride['rentalDetails']['hours']
        : null;
    final seconds = remaining.inSeconds.clamp(0, 86400);
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 8, 15),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [requestNavy, Color(0xFF2A3959)],
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.local_taxi, color: requestNavy, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expired ? 'Offer expired' : 'New Ride Request',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (close != null)
                  IconButton(
                    tooltip: 'Close ride request',
                    onPressed: busy ? null : close,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      requestSector(ride),
                      style: const TextStyle(
                        color: Color(0xFF21632B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _Location(
                  label: 'Pickup',
                  address: details['pickup'],
                  color: requestGreen,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 35),
                  child: Divider(height: 1, color: Color(0xFFE4E5EB)),
                ),
                _Location(
                  label: 'Drop',
                  address: details['drop'],
                  color: const Color(0xFFEF3E47),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FB),
                    border: Border.all(color: const Color(0xFFE9EBF0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 23),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              details['vehicle'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.route, size: 20),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              details['distance'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 18,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              details['duration'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (hours != null)
                            Text(
                              '$hours hours',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (details['fare'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF9EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF008A1A),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Ride Price',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          details['fare'],
                          style: const TextStyle(
                            color: Color(0xFF008A1A),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  expired
                      ? 'No longer available'
                      : 'Time remaining: ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: const Color(0xFFDE2C38),
                          side: const BorderSide(color: Color(0xFFEF414A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy || expired ? null : reject,
                        icon: const Icon(Icons.close),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: requestGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy || expired ? null : accept,
                        icon: const Icon(Icons.check),
                        label: Text(
                          busy ? 'Updating…' : 'Accept',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Location extends StatelessWidget {
  final String label, address;
  final Color color;
  const _Location({
    required this.label,
    required this.address,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, color: color, size: 29),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF525B6A), fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

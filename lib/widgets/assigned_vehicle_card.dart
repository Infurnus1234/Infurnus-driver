import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/operations_theme.dart';
import 'reference_components.dart';

class AssignedVehicleCard extends StatelessWidget {
  final Map<String, dynamic>? vehicle;
  final bool loading, canManage;
  final VoidCallback retry;
  const AssignedVehicleCard({
    super.key,
    required this.vehicle,
    required this.loading,
    required this.retry,
    this.canManage = true,
  });
  @override
  Widget build(BuildContext context) {
    final value = vehicle;
    if (value == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your vehicle',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                loading ? 'Loading assigned vehicle…' : 'Unassigned · Enter a vehicle code when you are ready to join.',
              ),
              TextButton(
                onPressed: loading || !canManage
                    ? null
                    : () => context.push('/driver/assignment'),
                child: const Text('Manage vehicle assignment'),
              ),
            ],
          ),
        ),
      );
    }
    final photo = value['photoUrl']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your assigned vehicle',
              style: TextStyle(fontSize: 12, color: Ops.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                            photo,
                            fit: BoxFit.contain,
                            semanticLabel: 'Assigned vehicle front photograph',
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: SizedBox.square(
                                      dimension: 24,
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                            errorBuilder: (_, _, _) =>
                                _missing('Photo unavailable', retry),
                          )
                        : _missing(
                            value['photoStatus'] == 'unavailable'
                                ? 'Photo unavailable'
                                : 'No front photo uploaded',
                            value['photoStatus'] == 'unavailable'
                                ? retry
                                : null,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value['plateNumber']?.toString() ??
                            'Registration unavailable',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [value['make'], value['model']]
                            .where((v) => v != null && v.toString().isNotEmpty)
                            .join(' '),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value['category']?.toString().replaceAll('_', ' ') ??
                            'Category unavailable',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Ops.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  value['verificationStatus']?.toString() ?? 'Unknown',
                ),
                Text(
                  value['isActive'] == true
                      ? 'Active'
                      : value['isActive'] == false
                      ? 'Inactive'
                      : 'Assigned',
                ),
                if (value['operationalStatus'] != null)
                  Text(value['operationalStatus'].toString()),
              ],
            ),
            if (canManage)
              TextButton(
                onPressed: loading
                    ? null
                    : () => context.push('/driver/assignment'),
                child: const Text('Manage or change vehicle'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _missing(String message, VoidCallback? retry) => Container(
    color: Ops.backgroundSecondary,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_outlined,
            size: 20,
            color: Ops.textSecondary,
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (retry != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
              ),
              onPressed: retry,
              child: const Text('Retry photo', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    ),
  );
}

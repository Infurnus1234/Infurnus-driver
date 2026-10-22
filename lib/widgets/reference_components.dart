import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/operations_theme.dart';
import '../providers/driver_session.dart';

class InfurnusBrand extends StatelessWidget {
  final String? name;
  const InfurnusBrand({super.key, this.name});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (name != null) ...[
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/profile'),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: Ops.surfaceOverlay,
            child: Text(
              name!.trim().isEmpty ? 'D' : name!.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: Ops.success,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      const Text(
        'N',
        style: TextStyle(
          color: Ops.success,
          fontWeight: FontWeight.w900,
          fontSize: 25,
        ),
      ),
      const SizedBox(width: 5),
      const Flexible(
        child: Text(
          'INFURNUS',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Ops.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    ],
  );
}

Future<void> showModeSwitcher(BuildContext context) async {
  final session = context.read<DriverSession>();
  if (!session.api.hasDriverRole || !session.api.hasFleetRole || session.busy) {
    return;
  }
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Switch Mode',
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            for (final mode in ['driver', 'fleet_owner'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: session.api.providerMode == mode
                          ? Ops.actionPrimary
                          : Ops.borderSubtle,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.pop(sheet, mode),
                    leading: Icon(
                      mode == 'driver'
                          ? Icons.directions_car_outlined
                          : Icons.business_outlined,
                      color: session.api.providerMode == mode
                          ? Ops.success
                          : Ops.textPrimary,
                    ),
                    title: Text(
                      mode == 'driver' ? 'Driver Mode' : 'Fleet Owner Mode',
                    ),
                    subtitle: Text(
                      mode == 'driver'
                          ? 'Drive and earn with your vehicle'
                          : 'Manage your fleet, vehicles and drivers',
                    ),
                    trailing: session.api.providerMode == mode
                        ? const Icon(
                            Icons.check_circle,
                            color: Ops.actionPrimary,
                          )
                        : null,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  if (selected == null ||
      selected == session.api.providerMode ||
      !context.mounted) {
    return;
  }
  final ok = await session.switchMode(selected);
  if (!context.mounted) return;
  if (ok) {
    context.go(session.landingPath);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.error ?? 'Unable to switch mode. Try again.'),
      ),
    );
  }
}

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final combined = session.api.hasDriverRole && session.api.hasFleetRole;
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        backgroundColor: Ops.surfaceOverlay,
        side: BorderSide.none,
        avatar: Icon(
          session.api.providerMode == 'driver'
              ? Icons.directions_car_outlined
              : Icons.business_outlined,
          size: 18,
          color: Ops.success,
        ),
        label: Text(
          session.api.providerMode == 'driver'
              ? 'Driver Mode'
              : 'Fleet Owner Mode',
          style: const TextStyle(color: Ops.success),
        ),
        onPressed: combined && !session.busy
            ? () => showModeSwitcher(context)
            : null,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final good = [
      'APPROVED',
      'VERIFIED',
      'ACTIVE',
      'COMPLETED',
    ].contains(normalized);
    final bad = [
      'REJECTED',
      'CANCELLED',
      'INACTIVE',
      'EXPIRED',
    ].contains(normalized);
    final color = good
        ? Ops.success
        : bad
        ? Ops.error
        : Ops.warning;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          status
              .toLowerCase()
              .split('_')
              .map(
                (s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}',
              )
              .join(' '),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Actual ledger rows only; no illustrative earnings or invented growth data.
class SettlementBars extends StatelessWidget {
  final List<Map> rows;
  const SettlementBars({super.key, required this.rows});
  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) => a['day'].toString().compareTo(b['day'].toString()));
    final visible = sorted
        .skip(sorted.length > 7 ? sorted.length - 7 : 0)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final values = visible
        .map((r) => num.tryParse(r['netPaise'].toString()) ?? 0)
        .toList();
    final maxValue = values.fold<double>(
      1,
      (m, v) => v.abs() > m ? v.abs().toDouble() : m,
    );
    final signed = values.any((v) => v < 0);
    return SizedBox(
      height: 104 + MediaQuery.textScalerOf(context).scale(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < visible.length; i++)
            Expanded(
              child: Tooltip(
                message:
                    '${visible[i]['day']}: ₹${(values[i] / 100).toStringAsFixed(2)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 90,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final baseline = signed ? 45.0 : 90.0;
                          final height =
                              (values[i].abs() / maxValue * (signed ? 40 : 80))
                                  .clamp(2.0, signed ? 40.0 : 80.0);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              if (signed)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: baseline,
                                  child: const Divider(height: 1),
                                ),
                              Positioned(
                                top: values[i] < 0
                                    ? baseline
                                    : baseline - height,
                                child: Container(
                                  width: 16,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: values[i] < 0
                                        ? Ops.error
                                        : Ops.actionPrimary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visible[i]['day']
                          .toString()
                          .split('T')
                          .first
                          .split('-')
                          .last,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Ops.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

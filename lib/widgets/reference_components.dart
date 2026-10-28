import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/operations_theme.dart';
import '../providers/driver_session.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? InfurnusTheme.surfaceCard,
      borderRadius: BorderRadius.circular(InfurnusTheme.r16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InfurnusTheme.r16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(InfurnusTheme.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InfurnusTheme.r16),
            border: border ?? Border.all(color: InfurnusTheme.borderSubtle),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(InfurnusTheme.s16),
      border: Border.all(
        color: isDestructive
            ? InfurnusTheme.dangerRed.withValues(alpha: 0.3)
            : InfurnusTheme.borderSubtle,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDestructive
                  ? InfurnusTheme.dangerRed.withValues(alpha: 0.1)
                  : InfurnusTheme.iconBoxBg,
              borderRadius: BorderRadius.circular(InfurnusTheme.r12),
            ),
            child: Icon(
              icon,
              color: isDestructive
                  ? InfurnusTheme.dangerRed
                  : InfurnusTheme.textDark,
              size: 22,
            ),
          ),
          const SizedBox(width: InfurnusTheme.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: InfurnusTheme.interStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDestructive
                        ? InfurnusTheme.dangerRed
                        : InfurnusTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: InfurnusTheme.interStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: InfurnusTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: InfurnusTheme.s8),
          trailing ??
              Icon(
                Icons.chevron_right,
                color: isDestructive
                    ? InfurnusTheme.dangerRed
                    : InfurnusTheme.textMuted,
                size: 20,
              ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: InfurnusTheme.buttonBlack,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InfurnusTheme.r16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text,
                style: InfurnusTheme.interStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? InfurnusTheme.infoBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: InfurnusTheme.interStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(InfurnusTheme.s16),
      decoration: BoxDecoration(
        color: InfurnusTheme.dangerRed.withValues(alpha: 0.05),
        border: Border.all(
          color: InfurnusTheme.dangerRed.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(InfurnusTheme.r16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: InfurnusTheme.dangerRed,
            size: 24,
          ),
          const SizedBox(width: InfurnusTheme.s12),
          Expanded(
            child: Text(
              message,
              style: InfurnusTheme.interStyle(
                fontSize: 13,
                color: InfurnusTheme.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: InfurnusTheme.s8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: InfurnusTheme.primaryGreen,
            ),
            child: Text(
              'Retry',
              style: InfurnusTheme.interStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(InfurnusTheme.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: InfurnusTheme.iconBoxBg,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(icon, size: 36, color: InfurnusTheme.textMuted),
          ),
          const SizedBox(height: InfurnusTheme.s16),
          Text(
            title,
            style: InfurnusTheme.interStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: InfurnusTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: InfurnusTheme.s8),
          Text(
            subtitle,
            style: InfurnusTheme.interStyle(
              fontSize: 14,
              color: InfurnusTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const SkeletonLoader({
    super.key,
    this.height = 20,
    this.width = double.infinity,
    this.radius = InfurnusTheme.r12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: InfurnusTheme.borderSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// Legacy compatibility components used across existing screens
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
      Image.asset(
        'assets/images/infurnus_logo.png',
        width: 34,
        height: 34,
        fit: BoxFit.contain,
        semanticLabel: 'INFURNUS logo',
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/operations_theme.dart';

import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';

/// Registration intent only. Server-verified claims determine account access.
class ProviderRoleCards extends StatelessWidget {
  final String? selected;
  final ValueChanged<String>? onChanged;
  const ProviderRoleCards({super.key, this.selected, this.onChanged});
  static const options = [
    (
      'driver',
      'Driver',
      'Drive with your own vehicle or one assigned by a fleet.',
      Icons.directions_car_outlined,
    ),
    (
      'driver_fleet_owner',
      'Driver + Fleet Owner',
      'Earn as a driver and manage your vehicles and drivers.',
      Icons.swap_horiz_rounded,
    ),
    (
      'fleet_owner',
      'Fleet Owner',
      'Manage your fleet, assign vehicles and monitor your business.',
      Icons.business_outlined,
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final option in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Semantics(
            selected: selected == option.$1,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onChanged == null ? null : () => onChanged!(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: selected == option.$1
                      ? const Color(0xFFE2F7E8)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == option.$1
                        ? Ops.actionPrimary
                        : const Color(0xFFDDE4DF),
                    width: selected == option.$1 ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(option.$4, color: Ops.actionPrimary, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$2,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.$3,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Ops.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected == option.$1
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected == option.$1
                          ? Ops.actionPrimary
                          : const Color(0xFF89958E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _role, _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Choose your account'),
      leading: IconButton(
        tooltip: 'Back to login',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/login'),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'How will you use INFURNUS?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose the account that fits your work. Existing accounts keep their registered role.',
                style: TextStyle(color: Ops.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 26),
              ProviderRoleCards(
                selected: _role,
                onChanged: (value) => setState(() {
                  _role = value;
                  _error = null;
                }),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (context.watch<DriverSession>().error != null)
                Text(
                  context.watch<DriverSession>().error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                style: Ops.darkButton,
                onPressed: () async {
                  if (_role == null) {
                    setState(
                      () => _error = 'Select an account type to continue.',
                    );
                    return;
                  }
                  final s = context.read<DriverSession>();
                  if (s.authenticated) {
                    if (await s.selectInitialRole(_role!) && context.mounted) {
                      context.go(s.landingPath);
                    }
                  } else {
                    context.go('/register?role=$_role');
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

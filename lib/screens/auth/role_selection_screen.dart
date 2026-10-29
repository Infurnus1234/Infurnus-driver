import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            selected: selected == option.$1,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onChanged == null ? null : () => onChanged!(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected == option.$1
                      ? const Color(0xFFF0FDF4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected == option.$1
                        ? Ops.actionPrimary
                        : const Color(0xFFE2E8F0),
                    width: selected == option.$1 ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected == option.$1
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        option.$4,
                        color: selected == option.$1
                            ? Ops.actionPrimary
                            : const Color(0xFF475569),
                        size: 24,
                      ),
                    ),
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
                              color: Ops.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                          : const Color(0xFF94A3B8),
                      size: 22,
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
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Ops.textPrimary,
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  children: [
                    // Stylized top illustration badge matching Ola/Uber visual reference
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: const [
                              Positioned(
                                top: 6,
                                child: Icon(
                                  Icons.directions_car,
                                  size: 22,
                                  color: Ops.actionPrimary,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                child: Icon(
                                  Icons.article_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'How will you use INFURNUS?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: Ops.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To continue driving with INFURNUS, please select an option. If you have multiple vehicles, proceed as Fleet Operator. To drive independently, proceed as Driver Partner.',
                      style: TextStyle(
                        color: Ops.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What would you like to register as?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Ops.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ProviderRoleCards(
                      selected: _role,
                      onChanged: (value) => setState(() {
                        _role = value;
                        _error = null;
                      }),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (context.watch<DriverSession>().error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          context.watch<DriverSession>().error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: Ops.darkButton.copyWith(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        onPressed: () async {
                          if (_role == null) {
                            setState(
                              () => _error =
                                  'Select an account type to continue.',
                            );
                            return;
                          }
                          final s = context.read<DriverSession>();
                          if (s.authenticated) {
                            if (await s.selectInitialRole(_role!) &&
                                context.mounted) {
                              context.go(s.landingPath);
                            }
                          } else {
                            context.go('/register?role=$_role&via=email_phone');
                          }
                        },
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

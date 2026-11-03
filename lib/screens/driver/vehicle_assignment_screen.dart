import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';

class VehicleAssignmentScreen extends StatefulWidget {
  const VehicleAssignmentScreen({super.key});

  @override
  State<VehicleAssignmentScreen> createState() =>
      _VehicleAssignmentScreenState();
}

class _VehicleAssignmentScreenState extends State<VehicleAssignmentScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      context.read<DriverSession>().assignmentPreview = null;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final preview = session.assignmentPreview;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle assignment')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Enter the six-digit vehicle code from your Fleet Owner.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  enabled: !session.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Vehicle assignment code',
                    errorText: _error ?? session.error,
                    helperText: 'Leading zeroes count toward all six digits.',
                  ),
                  onChanged: (_) {
                    setState(() {
                      _error = null;
                      session.assignmentPreview = null;
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: session.busy
                        ? null
                        : () => context.push('/support-tickets'),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Request a new code'),
                  ),
                ),
                FilledButton(
                  style: Ops.darkButton,
                  onPressed: session.busy
                      ? null
                      : () async {
                          if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
                            setState(
                              () => _error = 'Enter all six digits, including any leading zeroes.',
                            );
                            return;
                          }
                          await session.previewAssignment(_code.text);
                        },
                  child: Text(
                    session.busy
                        ? 'Checking code…'
                        : 'Check vehicle assignment',
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    '${preview['vehicle']?['make'] ?? ''} ${preview['vehicle']?['model'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Registration: ${preview['vehicle']?['plateNumber'] ?? 'Unavailable'}',
                  ),
                  Text(
                    'Fleet: ${preview['owner']?['businessName'] ?? 'Unavailable'}',
                  ),
                  FilledButton(
                    onPressed: session.busy
                        ? null
                        : () async {
                            if (await session.claimAssignment(_code.text) &&
                                context.mounted) {
                              if (session.api.roleFlowEnabled) {
                                context.go(session.landingPath);
                              } else {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                    child: Text(
                      session.busy
                          ? 'Confirming vehicle…'
                          : 'Confirm assigned vehicle',
                    ),
                  ),
                ],
                if (session.assignedVehicleError != null ||
                    session.refreshWarning != null)
                  TextButton(
                    onPressed: session.busy
                        ? null
                        : () async {
                            final expected = preview?['vehicle']?['id'];
                            if (await session.refresh() &&
                                expected != null &&
                                session.assignedVehicle?['id'] == expected &&
                                context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Refresh assignment status'),
                  ),
                TextButton(
                  onPressed: session.busy
                      ? null
                      : () async {
                          if (await session.deferDashboardSetup() &&
                              context.mounted) {
                            context.go(session.landingPath);
                          }
                        },
                  child: const Text('Skip for now'),
                ),
                if (session.busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

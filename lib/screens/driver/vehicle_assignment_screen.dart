import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../core/operations_theme.dart';

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
    final s = context.watch<DriverSession>();
    final preview = s.assignmentPreview;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle assignment')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Enter the six-digit vehicle code provided by your Fleet Owner. Joining is optional for dashboard access. Your account, Fleet membership, Driver approval and vehicle eligibility are checked by the backend.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            enabled: !s.busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Six-digit vehicle assignment code',
            ),
            onChanged: (_) {
              setState(() {
                _error = null;
                s.assignmentPreview = null;
              });
            },
          ),
          FilledButton(
            style: Ops.darkButton,
            onPressed: s.busy
                ? null
                : () async {
                    if (!RegExp(r'^\d{6}$').hasMatch(_code.text)) {
                      setState(
                        () => _error = 'Enter all six digits, including any leading zeroes.',
                      );
                      return;
                    }
                    await s.previewAssignment(_code.text);
                  },
            child: const Text('Check vehicle assignment'),
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
              onPressed: s.busy
                  ? null
                  : () async {
                      if (await s.claimAssignment(_code.text) &&
                          context.mounted) {
                        if (s.api.roleFlowEnabled) {
                          context.go(s.landingPath);
                        } else {
                          Navigator.of(context).pop();
                        }
                      }
                    },
              child: const Text('Confirm assigned vehicle'),
            ),
          ],
          if (s.error != null || s.refreshWarning != null)
            TextButton(
              onPressed: s.busy
                  ? null
                  : () async {
                      final expected = preview?['vehicle']?['id'];
                      if (await s.refresh() &&
                          expected != null &&
                          s.assignedVehicle?['id'] == expected &&
                          context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Refresh assignment status'),
            ),
          TextButton(
            onPressed: s.busy
                ? null
                : () async {
                    if (await s.deferDashboardSetup() && context.mounted) {
                      context.go(s.landingPath);
                    }
                  },
            child: const Text('Skip for now'),
          ),
          if (s.busy) const LinearProgressIndicator(),
          if (_error != null || s.error != null)
            Text(
              _error ?? s.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

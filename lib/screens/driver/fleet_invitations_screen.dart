import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';

class FleetInvitationsScreen extends StatefulWidget {
  const FleetInvitationsScreen({super.key});
  @override
  State<FleetInvitationsScreen> createState() => _FleetInvitationsScreenState();
}

class _FleetInvitationsScreenState extends State<FleetInvitationsScreen> {
  int _version = 0;
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final session = context.read<DriverSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Fleet invitations')),
      body: ApiPanel(
        key: ValueKey(_version),
        api: session.api,
        path: '/provider/fleet-invitations',
        builder: (context, value) => Column(
          children: [
            const Text(
              'Accepting allows this Fleet to save your onboarding profile and documents. Vehicle assignment still requires a valid six-digit code. Driving approval is separate.',
            ),
            if ((value as List).isEmpty)
              const OpsEmpty('No pending Fleet invitations.'),
            for (final row in value)
              Card(
                child: ListTile(
                  title: Text(row['businessName'].toString()),
                  subtitle: Text('Expires: ${row['expiresAt']}'),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final accept = await confirmOperation(
                              context,
                              'Allow Fleet profile management?',
                              row['businessName'].toString(),
                            );
                            if (!accept || !mounted) return;
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            try {
                              await session.api.request(
                                'POST',
                                '/provider/fleet-invitations/${row['id']}/accept',
                                body: {},
                              );
                              if (mounted) setState(() => _version++);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _error = e.toString());
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Accept'),
                  ),
                ),
              ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    );
  }
}

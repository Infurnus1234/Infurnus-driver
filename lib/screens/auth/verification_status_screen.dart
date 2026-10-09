import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import '../../widgets/google_sign_in_button.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<DriverSession>();
    if (!s.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Driver verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Statuses and review decisions are supplied by INFURNUS. Refresh to check for updates.',
          ),
          GoogleSignInButton(
            label: 'Link Google account',
            enabled: !s.busy,
            onIdToken: (token) async {
              final success = await s.linkGoogle(token);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Google linked. You can now sign in with Google. Driver approval remains unchanged.',
                    ),
                  ),
                );
              }
            },
          ),
          if (s.error != null)
            Text(s.error!, style: const TextStyle(color: Colors.red)),
          Card(
            child: ListTile(
              title: const Text('Driver profile'),
              subtitle: Text(
                '${statusLabel(s.profile?['verificationStatus'])}\n${s.profile?['rejectionReason'] ?? ''}',
              ),
            ),
          ),
          if (s.profile?['licenseExpiry'] != null &&
              s.profile!['licenseExpiry'].toString().compareTo(
                    OnboardingRules.today(),
                  ) <
                  0)
            const Text(
              'Driving licence expired. Update your licence and request review.',
            ),
          for (final d in s.documents)
            Card(
              child: ListTile(
                title: Text(
                  ((d['documentMetadata'] as Map?)?['documentCode'] ??
                          d['documentType'])
                      .toString()
                      .replaceAll('_', ' '),
                ),
                subtitle: Text(
                  '${OnboardingRules.expired(d) ? 'Expired — resubmission required' : d['verificationStatus']}\n${d['rejectionReason'] ?? ''}',
                ),
              ),
            ),
          for (final a in s.approvals)
            Card(
              child: ListTile(
                title: Text(a['request_type'].toString().replaceAll('_', ' ')),
                subtitle: Text(
                  '${statusLabel(a['status'])}\n${a['rejection_reason'] ?? ''}${a['requested_changes'] == null ? '' : '\nRequested changes: ${a['requested_changes']}'}',
                ),
              ),
            ),
          for (final a in s.applications)
            Card(
              child: ListTile(
                title: const Text('Fleet application'),
                subtitle: Text('${a['status']}\n${a['reviewReason'] ?? ''}'),
              ),
            ),
          if (s.applications.any((a) => a['status'] == 'CHANGES_REQUESTED'))
            const Text(
              'Correct your details/documents and contact your fleet reviewer. The backend has no driver application amendment endpoint.',
            ),
          Text(
            s.assignedVehicle == null
                ? 'No approved active vehicle assigned.'
                : 'Assigned vehicle: ${s.assignedVehicle!['plateNumber']}',
          ),
          FilledButton(
            onPressed: s.busy ? null : s.refresh,
            child: Text(s.busy ? 'Refreshing…' : 'Refresh status'),
          ),
          OutlinedButton(
            onPressed: s.busy ? null : () => context.go('/onboarding'),
            child: const Text('Continue / correct onboarding'),
          ),
          OutlinedButton(
            onPressed: s.busy ? null : () => context.go('/provider-assets'),
            child: const Text('Owned vehicles & vehicle documents'),
          ),
          if (s.api.hasFleetRole)
            TextButton(
              onPressed: s.busy
                  ? null
                  : () async {
                      final ok = await s.switchMode('fleet_owner');
                      if (context.mounted && ok) context.go(s.landingPath);
                    },
              child: const Text('Switch to Fleet mode'),
            ),
          if (s.dashboardAllowed)
            FilledButton(
              onPressed: () => context.go('/driver/dashboard'),
              child: const Text('Open driver dashboard'),
            ),
          TextButton(
            onPressed: s.busy
                ? null
                : () async {
                    await s.logout();
                    if (context.mounted) context.go('/login');
                  },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

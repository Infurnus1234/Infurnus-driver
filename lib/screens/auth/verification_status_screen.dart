import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../models/onboarding_journey.dart';
import '../../models/provider_status.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<DriverSession>();
    final tasks = OnboardingJourney.tasks(s)
        .where((t) => !['setup', 'summary', 'fleet'].contains(t.id))
        .toList();
    final pending = tasks
        .where(
          (t) =>
              t.rule != null &&
              OnboardingJourney.state(s.requirementDocument(t.rule!.code)) ==
                  RequirementState.pending,
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: s.busy ? null : s.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                s.dashboardAllowed
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                s.dashboardAllowed
                    ? 'Your verification application'
                    : 'Your application, at a glance',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                s.dashboardAllowed
                    ? 'Dashboard access is available. Driving requires approved licence, profile and vehicle verification.'
                    : 'Complete the required licence submission to open your dashboard. Approval is reviewed separately.',
              ),
              const SizedBox(height: 16),
              Text(
                '${s.missingUploads.length} required uploads missing • $pending pending review',
              ),
              const SizedBox(height: 24),
              Text(
                'Driver profile: ${statusLabel(s.profile?['verificationStatus'])}',
              ),
              if (s.profile != null && rejectionReason(s.profile!) != null)
                Text('Reviewer: ${rejectionReason(s.profile!)}'),
              Text(
                'Application: ${s.onboardingReceipt?['verificationStatus'] ?? 'Not submitted'}',
              ),
              if (s.onboardingReceipt?['submitted_at'] != null)
                Text('Submitted: ${s.onboardingReceipt!['submitted_at']}'),
              for (final review
                  in (s.onboardingReceipt?['review'] as List?) ?? const [])
                if (review['rejection_reason'] != null)
                  Text('Correction required: ${review['rejection_reason']}'),
              const Divider(height: 32),
              for (final task in tasks)
                Builder(
                  builder: (_) {
                    final doc = task.rule == null
                        ? null
                        : s.requirementDocument(task.rule!.code);
                    final ready = OnboardingJourney.satisfied(task, s);
                    final state = task.rule == null
                        ? null
                        : OnboardingJourney.state(doc);
                    final text = task.id == 'licence'
                        ? (ready
                              ? 'Details saved — ${statusLabel(s.profile?['verificationStatus'])}'
                              : 'Licence details need correction')
                        : task.id == 'vehicle'
                        ? (s.assignedVehicle == null
                              ? 'No active assignment confirmed'
                              : 'Assigned: ${s.assignedVehicle!['plateNumber']}')
                        : OnboardingJourney.label(state!);
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            state == RequirementState.approved
                                ? Icons.verified_outlined
                                : ready
                                ? Icons.cloud_done_outlined
                                : Icons.edit_outlined,
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            '${s.deferredSteps.contains(task.id) ? 'Deferred — ' : ''}$text${doc != null && rejectionReason(doc) != null ? '\nReviewer: ${rejectionReason(doc)}' : ''}',
                          ),
                          trailing: TextButton(
                            onPressed: s.busy
                                ? null
                                : () => context.go(
                                    '/onboarding?task=${Uri.encodeQueryComponent(task.id)}',
                                  ),
                            child: Text(ready ? 'View' : 'Fix'),
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),
              for (final doc in s.partnerDocuments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    ((doc['metadata'] as Map?)?['documentCode'] ??
                            doc['documentType'] ??
                            'Vehicle document')
                        .toString()
                        .replaceAll('_', ' '),
                  ),
                  subtitle: Text(
                    '${statusLabel(doc['status'])}${rejectionReason(doc) == null ? '' : '\n${rejectionReason(doc)}'}\nUpdated: ${doc['updatedAt'] ?? doc['uploadedAt'] ?? 'Unavailable'}',
                  ),
                  trailing: TextButton(
                    onPressed: s.busy
                        ? null
                        : () => context.push('/provider-assets'),
                    child: const Text('Manage'),
                  ),
                ),
              if (s.onboardingReceipt != null)
                TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          await s.submitOnboarding();
                        },
                  child: const Text('Submit updates for review'),
                ),
              // Approval requests are history for the same entities, not extra cards.
              if (s.applications.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Fleet application'),
                for (final a in {
                  for (final a in s.applications) a['id']: a,
                }.values)
                  Text(
                    '${statusLabel(a['status'])}${a['reviewReason'] == null ? '' : ' — ${a['reviewReason']}'}',
                  ),
              ],
              if (s.error != null)
                Text(
                  s.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () => context.go(
                        s.dashboardAllowed
                            ? '/driver/dashboard'
                            : '/onboarding',
                      ),
                child: Text(
                  s.dashboardAllowed
                      ? 'Open driver dashboard'
                      : 'Continue onboarding',
                ),
              ),
              TextButton(
                onPressed: s.busy ? null : s.refresh,
                child: const Text('Check for review updates'),
              ),
              TextButton(
                onPressed: () => context.push('/support-tickets'),
                child: const Text('Contact support'),
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
        ),
      ),
    );
  }
}

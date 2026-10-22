import '../../widgets/operations.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../models/onboarding_rules.dart';
import '../../core/operations_theme.dart';
import 'guided_document_capture.dart';
import 'driver_onboarding_screen.dart';

class RoleOnboardingScreen extends StatefulWidget {
  const RoleOnboardingScreen({super.key, this.editStep});
  final String? editStep;
  @override
  State<RoleOnboardingScreen> createState() => _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends State<RoleOnboardingScreen> {
  final _email = TextEditingController();
  final _photo = CaptureDraft();
  final _first = TextEditingController(), _last = TextEditingController();
  String? _error;
  bool _working = false;
  @override
  void dispose() {
    _email.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() fn) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DriverSession>(), data = s.roleEnrolment;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final steps = List<String>.from(data['steps'] as List),
        progress = Map<String, dynamic>.from(data['progress'] as Map);
    final remaining = steps
        .where(
          (x) => x == 'code'
              ? data['codeVerified'] != true
              : !['skipped', 'completed'].contains(progress[x]),
        )
        .toList();
    final step =
        widget.editStep ?? (remaining.isEmpty ? 'finish' : remaining.first);
    const titles = {
      'code': 'Join a vehicle',
      'vehicle_assignment': 'Join a vehicle',
      'profile_photo': 'Your profile photo',
      'licence': 'Your driving licence',
      'details': 'Your Driver details',
      'business': 'Add your business',
      'driver': 'Add a Driver',
      'vehicle': 'Add a vehicle',
      'finish': 'You’re ready to continue',
    };
    final busy = _working || s.busy;
    Future<bool> save({required bool skip}) async {
      final ok = await s.enrolmentAction({'step': step, 'skipped': skip});
      if (ok && widget.editStep != null && context.mounted) {
        Navigator.of(context).pop();
      }
      return ok;
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: busy
                ? null
                : () async {
                    await s.logout();
                    if (context.mounted) context.go('/login');
                  },
          ),
        ],
        title: Text(
          s.api.role == 'fleet_owner'
              ? 'Fleet onboarding'
              : 'Driver onboarding',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'STEP ${steps.length - remaining.length + 1} OF ${steps.length + 1}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (steps.length - remaining.length) / (steps.length + 1),
            ),
            const SizedBox(height: 28),
            Text(
              titles[step]!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (step == 'vehicle_assignment' || step == 'code') ...[
              const Text(
                'Enter a six-digit vehicle code to join your Fleet vehicle, or skip for now and open your dashboard unassigned.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => context.push('/driver/assignment'),
                child: const Text('Enter six-digit vehicle code'),
              ),
            ] else if (step == 'profile_photo') ...[
              const Text(
                'Optional. Add a clear profile photo now or return later.',
              ),
              const SizedBox(height: 16),
              if (widget.editStep == 'profile_photo')
                ApiPanel(
                  embedded: true,
                  api: s.api,
                  path: '/provider/enrolment/photo',
                  builder: (_, data) => data == null
                      ? const Text('No saved profile photo.')
                      : Image.network(
                          data['accessUrl'] as String,
                          height: 120,
                          errorBuilder: (_, _, _) =>
                              const Text('Saved photo preview is unavailable.'),
                        ),
                ),
              GuidedDocumentCapture(
                rule: const DocumentRule('profile_photo'),
                draft: _photo,
                scope: '${s.api.userId}:account-photo',
                showMetadata: false,
                disabled: busy,
                changed: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        final error = await validateCaptureDraft(
                          const DocumentRule('profile_photo'),
                          _photo,
                        );
                        if (error != null || _photo.files.length != 1) {
                          setState(
                            () => _error = error ?? 'Choose one profile photo.',
                          );
                          return false;
                        }
                        await s.api.request(
                          'POST',
                          '/provider/enrolment/photo',
                          files: _photo.files,
                          fileField: 'file',
                        );
                        return save(skip: false);
                      }),
                child: const Text('Upload & continue'),
              ),
            ] else if (step == 'licence') ...[
              const Text(
                'Optional for onboarding. Driver operations still require the applicable approval and compliance checks.',
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        if (s.api.providerMode != 'driver' &&
                            !await s.switchMode('driver')) {
                          return false;
                        }
                        if (!context.mounted) return false;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DriverOnboardingScreen(
                              initialTask: 'licence',
                              onSkip: () async {
                                if (await save(skip: true) && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              onSaved: () async {
                                if (await save(skip: false) &&
                                    context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                        );
                        return true;
                      }),
                child: const Text('Add licence details'),
              ),
            ] else if (step == 'driver') ...[
              const Text(
                'Invite an existing Driver by email. They accept from Account > Fleet invitations. Fleet association and driving approval remain separate.',
              ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Driver email'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        final invite = await s.api.request(
                          'POST',
                          '/provider/fleet-drivers',
                          body: {'email': _email.text.trim()},
                        );
                        if (context.mounted) {
                          await showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Fleet invitation'),
                              content: SelectableText(
                                'Invitation created. The Driver can accept from Account > Fleet invitations. Expires: ${invite['expiresAt']}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                        return save(skip: false);
                      }),
                child: const Text('Invite Driver'),
              ),
            ] else if (step == 'details') ...[
              TextField(
                controller: _first,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              TextField(
                controller: _last,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        if (!await s.saveAccountNames(
                          _first.text,
                          _last.text,
                        )) {
                          return false;
                        }
                        return save(skip: false);
                      }),
                child: const Text('Save details & continue'),
              ),
            ] else if (step == 'business' ||
                step == 'vehicle' ||
                step == 'details') ...[
              const Text(
                'This setup is optional. Saved information remains subject to the existing validation and approval rules.',
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => context.push(
                        step == 'details' ? '/profile' : '/onboarding/assets',
                      ),
                child: Text(
                  'Open ${step == 'details' ? 'profile' : step} setup',
                ),
              ),
              FilledButton(
                onPressed: busy ? null : () => _act(() => save(skip: false)),
                child: const Text('Continue with saved details'),
              ),
            ] else ...[
              const Text(
                'Your skipped steps stay incomplete and can be finished later. Onboarding does not approve Driver operations or vehicle assignments.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: Ops.darkButton,
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        if (s.api.hasFleetRole &&
                            s.api.providerMode != 'fleet_owner' &&
                            !await s.switchMode('fleet_owner')) {
                          return false;
                        }
                        final ok = await s.enrolmentAction({'complete': true});
                        if (ok && context.mounted) context.go(s.landingPath);
                        return ok;
                      }),
                child: const Text('Open dashboard'),
              ),
            ],
            if (step != 'finish')
              TextButton(
                onPressed: busy
                    ? null
                    : () => _act(() async {
                        if (step == 'vehicle_assignment' || step == 'code') {
                          final ok = await s.deferDashboardSetup();
                          if (ok && context.mounted) context.go(s.landingPath);
                          return ok;
                        }
                        return save(skip: true);
                      }),
                child: const Text('Skip for now'),
              ),
            if (busy) const LinearProgressIndicator(),
            if (_error != null || s.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error ?? s.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

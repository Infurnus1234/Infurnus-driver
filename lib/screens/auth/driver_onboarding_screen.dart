import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../core/operations_theme.dart';
import '../../models/onboarding_journey.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import 'guided_document_capture.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final String? initialTask;
  final CapturePicker? picker;
  final Future<void> Function()? onSaved;
  final Future<void> Function()? onSkip;
  const DriverOnboardingScreen({
    super.key,
    this.initialTask,
    this.picker,
    this.onSaved,
    this.onSkip,
  });
  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _licence = TextEditingController(),
      _expiry = TextEditingController(),
      _code = TextEditingController();
  final _first = TextEditingController(), _last = TextEditingController();
  final _drafts = <String, CaptureDraft>{};
  bool _draftsRestored = false;
  String? _current, _error, _licenceError, _expiryError;
  bool _saving = false, _initialized = false, _choosing = false;
  @override
  void dispose() {
    for (final c in [_licence, _expiry, _code, _first, _last]) {
      c.dispose();
    }

    super.dispose();
  }

  void _next(List<JourneyTask> tasks, int index) {
    if (!mounted) return;
    setState(() {
      _error = null;
      _current = tasks[(index + 1).clamp(0, tasks.length - 1)].id;
    });
  }

  Future<void> _continue(
    DriverSession s,
    List<JourneyTask> tasks,
    int index,
  ) async {
    if (_saving || s.busy) return;
    if (s.refreshWarning != null) {
      await s.refresh();
      return;
    }
    final task = tasks[index];
    for (final previous in tasks.take(index)) {
      if (previous.rule != null &&
          !s.deferredSteps.contains(previous.id) &&
          !OnboardingJourney.satisfied(previous, s)) {
        setState(() {
          _current = previous.id;
          _error = 'An earlier upload needs attention. Check its current server status.';
        });
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      bool ok = false;
      if (task.id == 'licence') {
        ok = await _saveLicence(
          s,
          task,
          _drafts.putIfAbsent(task.id, CaptureDraft.new),
        );
      } else if (task.rule != null) {
        final draft = _drafts.putIfAbsent(task.id, CaptureDraft.new);
        if (draft.files.isEmpty && OnboardingJourney.satisfied(task, s)) {
          ok = true;
        } else {
          final metadata = <String, String>{
            'uploadSource': draft.source,
            if (draft.number.trim().isNotEmpty)
              'documentNumber': draft.number.trim(),
            if (draft.expiry.trim().isNotEmpty)
              'expiresAt': draft.expiry.trim(),
          };
          final imageError = await validateCaptureDraft(task.rule!, draft);
          if (imageError != null) {
            setState(() => _error = imageError);
            return;
          }
          final error = OnboardingRules.validateFiles(
            task.rule!,
            draft.files,
            metadata,
          );
          if (error != null) {
            setState(() => _error = error);
            return;
          }
          ok = await s.uploadDocument(
            task.rule!,
            List.of(draft.files),
            metadata,
          );
          if (ok && !OnboardingJourney.satisfied(task, s)) {
            ok = false;
            _error = 'The upload response could not be confirmed in your saved requirements. Refresh and retry.';
          }
          if (ok) draft.files.clear();
        }
      } else if (task.id == 'account') {
        ok = await s.saveAccountNames(_first.text, _last.text);
      } else if (task.id == 'vehicle') {
        // The backend permits document review before assignment; operational
        // eligibility still requires an approved active vehicle.
        ok = true;
      } else if (task.id == 'summary') {
        ok = await s.submitOnboarding();
        if (ok && mounted) {
          context.go('/driver/dashboard');
          return;
        }
      }
      if (!mounted) return;
      if (ok && widget.onSaved != null) {
        await widget.onSaved!();
        return;
      }
      if (ok) {
        if (s.deferredSteps.contains(task.id)) {
          if (!await s.resumeStep(task.id)) return;
        }
        if (task.id == 'setup') {
          setState(() => _current = 'profile_photo');
        } else {
          _next(tasks, index);
        }
      } else {
        setState(
          () => _error ??=
              s.error ?? 'Complete this requirement before continuing.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _saveLicence(
    DriverSession s,
    JourneyTask task,
    CaptureDraft draft,
  ) async {
    draft.number = _licence.text.trim();
    draft.expiry = _expiry.text.trim();
    final input = <String, dynamic>{
      ...?s.profile,
      'licenseNumber': draft.number,
      'licenseExpiry': draft.expiry,
    };
    final metadata = <String, String>{
      'documentNumber': draft.number,
      'expiresAt': draft.expiry,
      'uploadSource': draft.source,
    };
    String? validation = OnboardingRules.validateProfile(input);
    if (validation == null && draft.files.isNotEmpty) {
      validation = await validateCaptureDraft(task.rule!, draft);
      validation ??= OnboardingRules.validateFiles(
        task.rule!,
        draft.files,
        metadata,
      );
    } else if (validation == null && !OnboardingJourney.satisfied(task, s)) {
      validation = 'Add the required licence photo or pages before continuing.';
    }
    if (validation != null) {
      if (mounted) setState(() => _error = validation);
      return false;
    }
    if (s.profile?['licenseNumber'] != draft.number ||
        s.profile?['licenseExpiry'] != draft.expiry) {
      if (!await s.saveProfile(input)) return false;
    }
    if (draft.files.isNotEmpty) {
      if (!await s.uploadDocument(task.rule!, List.of(draft.files), metadata)) {
        return false;
      }
      if (!OnboardingJourney.satisfied(task, s)) {
        if (mounted) {
          setState(
            () => _error = 'Your upload is not yet confirmed. Refresh the saved requirements before submitting again.',
          );
        }
        return false;
      }
      draft.files.clear();
    }
    return OnboardingJourney.satisfied(task, s);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DriverSession>();
    if (!_draftsRestored) {
      _drafts.addAll(
        s.onboardingDrafts.map(
          (key, value) => MapEntry(key, value as CaptureDraft),
        ),
      );
      _draftsRestored = true;
    }
    if (!s.authenticated || !s.onboardingLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver onboarding')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.error ?? 'Loading your requirements…'),
              TextButton(
                onPressed: s.busy ? null : s.refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final tasks = OnboardingJourney.tasks(s)
        .where((t) => widget.onSaved == null || t.id == 'licence')
        .toList();
    if (widget.onSaved == null &&
        ((s.account?['firstName']?.toString().trim() ?? '').isEmpty ||
            (s.account?['lastName']?.toString().trim() ?? '').isEmpty)) {
      tasks.insert(
        tasks.length - 1,
        const JourneyTask(
          'account',
          'Your account name',
          'Confirm the name associated with your application.',
        ),
      );
    }
    if (!_initialized) {
      _licence.text = s.profile?['licenseNumber']?.toString() ?? '';
      _expiry.text = s.profile?['licenseExpiry']?.toString() ?? '';
      _first.text = s.account?['firstName']?.toString() ?? '';
      _last.text = s.account?['lastName']?.toString() ?? '';
      final resume = OnboardingJourney.resume(tasks, s);
      final requestedId =
          ['setup', 'driver_license'].contains(widget.initialTask)
          ? 'licence'
          : widget.initialTask;
      final requested = tasks.indexWhere((t) => t.id == requestedId);
      _current = tasks[requested >= 0 ? requested : resume].id;
      final savedDraft = _drafts['licence'];
      if (savedDraft != null) {
        if (savedDraft.number.isNotEmpty) _licence.text = savedDraft.number;
        if (savedDraft.expiry.isNotEmpty) _expiry.text = savedDraft.expiry;
      }
      _initialized = true;
    }
    var index = tasks.indexWhere((t) => t.id == _current);
    if (index < 0) index = OnboardingJourney.resume(tasks, s);
    final task = tasks[index], blocked = _saving || s.busy || _choosing;
    final doc = task.rule == null
        ? null
        : s.requirementDocument(task.rule!.code);
    final draft = _drafts.putIfAbsent(task.id, () {
      final value = CaptureDraft();
      if (task.id == 'licence') {
        value.expiry = _expiry.text.trim();
        value.number = _licence.text.trim();
      }
      return value;
    });
    s.onboardingDrafts.addAll(_drafts);
    return PopScope(
      canPop: !blocked,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Driver onboarding'),
          leading: IconButton(
            tooltip: 'Previous step',
            icon: const Icon(Icons.arrow_back),
            onPressed: blocked
                ? null
                : () {
                    if (widget.onSaved != null) {
                      Navigator.of(context).pop();
                      return;
                    }
                    if (index > 0) {
                      setState(() {
                        _current = tasks[index - 1].id;
                        _error = null;
                      });
                    } else {
                      context.go('/verification-status');
                    }
                  },
          ),
          actions: [
            IconButton(
              tooltip: 'Support',
              icon: const Icon(Icons.support_agent),
              onPressed: blocked
                  ? null
                  : () => context.push('/support-tickets'),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              key: ValueKey(task.id),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                Text(
                  'STEP ${index + 1} OF ${tasks.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (index + 1) / tasks.length,
                  semanticsLabel:
                      'Onboarding progress, step ${index + 1} of ${tasks.length}',
                ),
                const SizedBox(height: 28),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  task.explanation,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (s.refreshWarning != null) ...[
                  Text(s.refreshWarning!),
                  TextButton(
                    onPressed: blocked ? null : s.refresh,
                    child: const Text('Refresh saved status'),
                  ),
                ],
                if (task.rule != null) ...[
                  if (doc != null) ...[
                    Text(
                      'Saved on server: ${OnboardingJourney.label(OnboardingJourney.state(doc))}',
                    ),
                    if (rejectionReason(doc) != null)
                      Text('Reviewer: ${rejectionReason(doc)}'),
                    const SizedBox(height: 16),
                  ],
                  GuidedDocumentCapture(
                    key: ValueKey(task.id),
                    rule: task.rule!,
                    showMetadata: task.id != 'licence',
                    draft: draft,
                    disabled: blocked,
                    picker: widget.picker,
                    scope:
                        s.api.userId ??
                        s.profile?['id']?.toString() ??
                        'driver',
                    onBusyChanged: (v) {
                      if (mounted) setState(() => _choosing = v);
                    },
                    changed: () => setState(() => _error = null),
                  ),
                ],
                if (task.id == 'licence' || task.id == 'setup') ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _licence,
                    enabled: !blocked,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Driving licence number *',
                      errorText: _licenceError,
                    ),
                    onChanged: (v) {
                      draft.number = v;
                      setState(() => _licenceError = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _expiry,
                    onChanged: (v) => draft.expiry = v,
                    enabled: !blocked,
                    decoration: InputDecoration(
                      labelText: 'Licence expiry (YYYY-MM-DD) *',
                      errorText: _expiryError,
                      suffixIcon: IconButton(
                        tooltip: 'Choose expiry date',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: blocked
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final initial =
                                    DateTime.tryParse(_expiry.text) ?? now;
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      initial.isBefore(DateTime(1900)) ||
                                          initial.isAfter(DateTime(2100))
                                      ? now
                                      : initial,
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null && mounted) {
                                  _expiry.text = date
                                      .toIso8601String()
                                      .substring(0, 10);
                                  draft.expiry = _expiry.text;
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.onSkip != null
                        ? 'Licence details are optional during onboarding. You may skip for now. Uploading does not approve Driver operations.'
                        : 'Your licence is required and cannot be skipped. Your photo and details are saved for review; uploading does not approve you to drive.',
                  ),
                ],
                if (task.id == 'account') ...[
                  TextField(
                    controller: _first,
                    enabled: !blocked,
                    decoration: const InputDecoration(
                      labelText: 'First name *',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _last,
                    enabled: !blocked,
                    decoration: const InputDecoration(labelText: 'Last name *'),
                  ),
                ],
                if (task.id == 'vehicle') ...[
                  if (s.assignedVehicle != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        s.assignedVehicle!['plateNumber']?.toString() ??
                            'Assigned vehicle',
                      ),
                      subtitle: const Text('Assignment confirmed by server'),
                    )
                  else ...[
                    TextField(
                      controller: _code,
                      enabled: !blocked,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'Fleet assignment code',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: blocked
                          ? null
                          : () async {
                              final ok = await s.previewAssignment(_code.text);
                              if (mounted) {
                                setState(() => _error = ok ? null : s.error);
                              }
                            },
                      child: const Text('Check assignment code'),
                    ),
                    if (s.assignmentPreview != null) ...[
                      Text(
                        'Vehicle: ${s.assignmentPreview?['vehicle']?['plateNumber'] ?? 'Fleet vehicle'}',
                      ),
                      FilledButton(
                        onPressed: blocked
                            ? null
                            : () async {
                                final ok = await s.claimAssignment(_code.text);
                                if (mounted) {
                                  setState(() => _error = ok ? null : s.error);
                                }
                              },
                        child: const Text('Confirm this assignment'),
                      ),
                    ],
                  ],
                  TextButton(
                    onPressed: blocked
                        ? null
                        : () => context.push('/onboarding/assets'),
                    child: const Text('I own a vehicle — open vehicle setup'),
                  ),
                ],
                if (task.id == 'fleet') ...[
                  const Text(
                    'Business and owned vehicle approval are separate from driver verification.',
                  ),
                  FilledButton(
                    onPressed: blocked
                        ? null
                        : () => context.push('/onboarding/assets'),
                    child: const Text('Open business setup'),
                  ),
                  TextButton(
                    onPressed: blocked ? null : () => _next(tasks, index),
                    child: const Text('Continue driver requirements'),
                  ),
                ],
                if (task.id == 'summary') ...[
                  Text(
                    'Operational documents still missing: ${s.missingUploads.length}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Submission requests a review; it does not make you eligible to drive. Pending reviews may be checked in your summary.',
                  ),
                  TextButton(
                    onPressed: blocked
                        ? null
                        : () => context.go('/verification-status'),
                    child: const Text('View saved verification summary'),
                  ),
                ],
                if (_error != null || s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error ?? s.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Saving to server',
                    ),
                  ),
                if (widget.onSkip != null)
                  TextButton(
                    onPressed: blocked ? null : widget.onSkip,
                    child: const Text('Skip for now'),
                  ),
                if (widget.onSkip == null && s.canDefer(task.id))
                  TextButton(
                    onPressed: blocked
                        ? null
                        : () async {
                            final ok = await s.deferStep(task.id);
                            if (ok && mounted) _next(tasks, index);
                          },
                    child: const Text('Skip for now'),
                  ),
                if (task.id != 'fleet')
                  FilledButton(
                    style: task.rule == null ? Ops.darkButton : null,
                    onPressed: blocked
                        ? null
                        : () => _continue(s, tasks, index),
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : task.id == 'licence'
                          ? 'Next'
                          : task.id == 'summary'
                          ? 'Submit for review'
                          : task.rule != null && draft.files.isNotEmpty
                          ? 'Upload & continue'
                          : task.rule != null
                          ? (OnboardingJourney.satisfied(task, s)
                                ? 'Continue'
                                : 'Upload & continue')
                          : task.id == 'vehicle'
                          ? 'Continue'
                          : 'Save & continue',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

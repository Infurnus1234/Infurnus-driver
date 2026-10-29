import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../core/operations_theme.dart';
import '../../models/onboarding_journey.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import 'guided_document_capture.dart';
import '../../widgets/private_document_preview.dart';
import '../../widgets/onboarding_cards.dart';

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
            if (draft.identityConsent) ...{
              'identityConsent': 'true',
              'maskedIdentity': 'true',
            },
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
        // When opened from the verification checklist for a specific task,
        // return there after a successful upload instead of advancing linearly.
        // When opened from the verification checklist for a specific task,
        // return to the checklist only after completing exactly that task.
        if (widget.initialTask != null &&
            task.id != 'summary' &&
            (task.id == widget.initialTask ||
                (['setup', 'driver_license'].contains(widget.initialTask) &&
                    task.id == 'licence'))) {
          if (mounted) {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go('/verification-status');
              return;
            }
          }
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
      if (draft.licenceClasses.trim().isNotEmpty)
        'licenceClasses': draft.licenceClasses.trim(),
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
      final requested = requestedId == null
          ? -1
          : tasks.indexWhere(
              (t) => t.id == requestedId || t.rule?.code == requestedId,
            );
      _current = tasks[requested >= 0 ? requested : resume].id;
      final savedDraft = _drafts['licence'];
      if (savedDraft != null) {
        if (savedDraft.number.isNotEmpty) _licence.text = savedDraft.number;
        if (savedDraft.expiry.isNotEmpty) _expiry.text = savedDraft.expiry;
      }
      _initialized = true;
    }
    var index = tasks.indexWhere(
      (t) => t.id == _current || (_current != null && t.rule?.code == _current),
    );
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                SegmentedProgressBar(
                  totalSegments: tasks.length,
                  completedSegments: index + 1,
                  activeColor: Ops.actionPrimary,
                  height: 4,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'STEP ${index + 1} OF ${tasks.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Ops.textSecondary,
                      ),
                    ),
                    Text(
                      index + 1 == tasks.length
                          ? 'Final step'
                          : '${tasks.length - index - 1} remaining',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Ops.textSecondary,
                      ),
                    ),
                  ],
                ),
                Offstage(
                  offstage: true,
                  child: LinearProgressIndicator(
                    value: (index + 1) / tasks.length,
                    semanticsLabel:
                        'Onboarding progress, step ${index + 1} of ${tasks.length}',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  task.explanation,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: Ops.textSecondary, height: 1.45),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            OnboardingJourney.state(doc) ==
                                    RequirementState.approved
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 20,
                            color:
                                OnboardingJourney.state(doc) ==
                                    RequirementState.approved
                                ? Ops.actionPrimary
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saved on server: ${OnboardingJourney.label(OnboardingJourney.state(doc))}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (rejectionReason(doc) != null)
                                  Text(
                                    'Reviewer: ${rejectionReason(doc)}',
                                    style: const TextStyle(
                                      color: Ops.error,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: blocked
                                ? null
                                : () => showPrivateDocumentPreview(
                                    context,
                                    s.api,
                                    doc['partnerId'] != null
                                        ? '/partners/${doc['partnerId']}/documents/${doc['id']}'
                                        : '/rides/driver/documents/${doc['id']}',
                                    task.rule!.label,
                                  ),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('Preview'),
                          ),
                        ],
                      ),
                    ),
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
                  TextFormField(
                    initialValue: draft.licenceClasses,
                    enabled: !blocked,
                    maxLength: 150,
                    decoration: InputDecoration(
                      labelText: 'Vehicle classes (optional)',
                      hintText: 'e.g. LMV, MCWG',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => draft.licenceClasses = v,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _licence,
                    enabled: !blocked,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Driving licence number *',
                      hintText: 'DL00000000000',
                      errorText: _licenceError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) {
                      draft.number = v;
                      setState(() => _licenceError = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _expiry,
                    onChanged: (v) => draft.expiry = v,
                    enabled: !blocked,
                    decoration: InputDecoration(
                      labelText: 'Licence expiry (YYYY-MM-DD) *',
                      hintText: 'YYYY-MM-DD',
                      errorText: _expiryError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.onSkip != null
                          ? 'Licence details are optional during onboarding. You may skip for now. Uploading does not approve Driver operations.'
                          : 'Your licence is required and cannot be skipped. Your photo and details are saved for review; uploading does not approve you to drive.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
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
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null || s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error ?? s.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Saving to server',
                    ),
                  ),
                if (widget.onSkip != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: blocked ? null : widget.onSkip,
                      child: const Text('Skip for now'),
                    ),
                  ),
                if (widget.onSkip == null && s.canDefer(task.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: blocked
                          ? null
                          : () async {
                              final ok = await s.deferStep(task.id);
                              if (ok && mounted) _next(tasks, index);
                            },
                      child: const Text('Skip for now'),
                    ),
                  ),
                if (task.id != 'fleet')
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style:
                          (task.rule == null
                                  ? Ops.darkButton
                                  : FilledButton.styleFrom(
                                      backgroundColor: Ops.actionPrimary,
                                      foregroundColor: Ops.onAction,
                                    ))
                              .copyWith(
                                shape: WidgetStatePropertyAll(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      onPressed: blocked
                          ? null
                          : () => _continue(s, tasks, index),
                      child: Text(
                        _saving
                            ? 'Saving…'
                            : task.id == 'licence'
                            ? 'Continue'
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

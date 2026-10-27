import 'package:flutter/material.dart';

import '../../widgets/fleet_model_field.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../providers/provider_assets.dart';
import '../../models/onboarding_rules.dart';
import '../../models/onboarding_journey.dart';
import '../../models/provider_status.dart';
import '../auth/guided_document_capture.dart';

/// Owned-provider prerequisites are kept separate from fleet assignment claims.
class GuidedProviderSetup extends StatefulWidget {
  final CapturePicker? picker;
  const GuidedProviderSetup({super.key, this.picker});
  @override
  State<GuidedProviderSetup> createState() => _GuidedProviderSetupState();
}

class _GuidedProviderSetupState extends State<GuidedProviderSetup> {
  ProviderAssets? _assets;
  final _business = TextEditingController();
  final _make = TextEditingController(),
      _model = TextEditingController(),
      _plate = TextEditingController(),
      _category = TextEditingController();
  final _drafts = <String, CaptureDraft>{};
  List<DocumentRule> _vehicleRules = [];
  String _task = 'business', _sector = 'logistics';
  String? _vehicleId, _error;
  bool _working = false, _choosing = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assets == null) {
      final session = context.read<DriverSession>();
      for (final entry in session.onboardingDrafts.entries.where(
        (e) => e.key.startsWith('provider:'),
      )) {
        _drafts[entry.key.substring('provider:'.length)] =
            entry.value as CaptureDraft;
      }
      _assets = ProviderAssets(session.api)..addListener(_changed);
      _load();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _assets!.refresh();
    if (!mounted) return;
    _business.text = _assets!.partner?['businessName']?.toString() ?? '';
    if (_assets!.partner != null) {
      _task = _assets!.approvedPartner ? 'vehicle' : 'business-documents';
    }
    if (_assets!.partner != null) {
      final pending = _assets!.vehicles
          .where(
            (v) =>
                providerStatus(
                  v['verificationStatus'] ?? v['approvalStatus'],
                ) !=
                ProviderStatus.approved,
          )
          .firstOrNull;
      if (pending != null) await _selectVehicle(pending);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _assets?.removeListener(_changed);
    _assets?.dispose();
    for (final c in [_business, _make, _model, _plate, _category]) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _selectVehicle(Map<String, dynamic> vehicle) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      _vehicleRules = await _assets!.vehicleRules(vehicle);
      _vehicleId = vehicle['id'] as String;
      _task = 'vehicle-documents';
    } catch (_) {
      _error = 'Unable to load this vehicle’s document policy. Retry.';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  bool _needs(DocumentRule rule, String? vehicleId) {
    final d = _assets!.documentFor(rule.code, vehicleId: vehicleId);
    return d == null ||
        (rule.requiresExpiry &&
            (d['expiresAt'] ?? (d['metadata'] as Map?)?['expiresAt']) ==
                null) ||
        OnboardingRules.expired({
          'documentMetadata': {
            ...?(d['metadata'] as Map?),
            'expiresAt': d['expiresAt'],
          },
        }) ||
        [
          ProviderStatus.rejected,
          ProviderStatus.changesRequested,
          ProviderStatus.expired,
        ].contains(providerStatus(d['status'])) ||
        (((d['metadata'] as Map?)?['pages'] as List?)?.length ?? 1) <
            rule.minimumPages;
  }

  @override
  Widget build(BuildContext context) {
    final a = _assets!;
    final busy = a.busy || _working || _choosing;
    final vehicle = _task == 'vehicle-documents';
    final required = (vehicle ? _vehicleRules : a.rules)
        .where(
          (r) =>
              r.required &&
              (vehicle
                  ? OnboardingJourney.vehicleCode(r.code)
                  : !OnboardingJourney.vehicleCode(r.code)),
        )
        .toList();
    final incomplete = required
        .where((r) => _needs(r, vehicle ? _vehicleId : null))
        .toList();
    final rule = incomplete.isEmpty ? null : incomplete.first;
    final selectedVehicle = a.vehicles
        .where((v) => v['id'] == _vehicleId)
        .firstOrNull;
    final reviewEntity = vehicle ? selectedVehicle : a.partner;
    final title = switch (_task) {
      'business' => 'Your provider business',
      'vehicle' => 'Add an owned vehicle',
      'vehicle-documents' => rule?.label ?? 'Vehicle review',
      _ => rule?.label ?? 'Business review',
    };
    Future<void> act(Future<bool> Function() action) async {
      if (busy) return;
      setState(() {
        _working = true;
        _error = null;
      });
      final ok = await action();
      if (mounted) {
        setState(() {
          _working = false;
          if (!ok) _error ??= a.error;
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider setup'),
        leading: IconButton(
          tooltip: 'Back to verification',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy
              ? null
              : () => context.go(
                  context.read<DriverSession>().roleEnrolment != null
                      ? '/role-onboarding'
                      : context.read<DriverSession>().api.providerMode ==
                            'driver'
                      ? '/onboarding?task=vehicle'
                      : '/profile',
                ),
        ),
      ),
      body: !a.loaded
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a.error ?? 'Loading provider requirements…'),
                  TextButton(
                    onPressed: busy ? null : _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  key: ValueKey('$_task:${rule?.code ?? ''}'),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      vehicle || _task == 'vehicle'
                          ? 'VEHICLE SETUP'
                          : 'BUSINESS SETUP',
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _task == 'business'
                          ? .2
                          : _task == 'business-documents'
                          ? .4
                          : .7,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _task == 'business'
                          ? 'Save the business that owns your vehicles. You can collect vehicle documents while business review is pending.'
                          : rule != null
                          ? 'One required document at a time. Your policy determines pages and expiry.'
                          : 'Review status comes from the server. Refresh to check for a decision.',
                    ),
                    const SizedBox(height: 24),
                    if (a.refreshWarning != null) ...[
                      Text(a.refreshWarning!),
                      TextButton(
                        onPressed: busy ? null : () => act(a.refresh),
                        child: const Text('Refresh saved status'),
                      ),
                    ],
                    if (_task == 'business') ...[
                      TextField(
                        controller: _business,
                        maxLength: 150,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Business name *',
                        ),
                      ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => act(() async {
                                if (_business.text.trim().isEmpty) {
                                  _error = 'Enter a business name.';
                                  return false;
                                }
                                final ok = await a.saveBusiness({
                                  'businessName': _business.text.trim(),
                                });
                                if (ok) _task = 'business-documents';
                                return ok;
                              }),
                        child: const Text('Save business & continue'),
                      ),
                    ] else if (_task == 'vehicle') ...[
                      for (final v in a.vehicles)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(v['plateNumber'].toString()),
                          subtitle: Text(
                            statusLabel(
                              v['verificationStatus'] ?? v['approvalStatus'],
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: busy ? null : () => _selectVehicle(v),
                            child: const Text('Documents'),
                          ),
                        ),
                      ...[
                        TextField(
                          controller: _make,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Make *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        IgnorePointer(
                          ignoring: busy,
                          child: FleetModelField(
                            api: context.read<DriverSession>().api,
                            make: _make,
                            model: _model,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _plate,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Registration / plate number *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _sector,
                          decoration: const InputDecoration(
                            labelText: 'Sector',
                          ),
                          items:
                              ['passenger', 'logistics', 'service', 'premium']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => _sector = v!),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _category,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                  if ([
                                    _make,
                                    _model,
                                    _plate,
                                    _category,
                                  ].any((c) => c.text.trim().isEmpty)) {
                                    _error = 'Complete make, model, registration and category.';
                                    return false;
                                  }
                                  final ok = await a.saveVehicle({
                                    'make': _make.text.trim(),
                                    'model': _model.text.trim(),
                                    'plateNumber': _plate.text.trim(),
                                    'sector': _sector,
                                    'category': _category.text.trim(),
                                    'isCommercial': true,
                                  });
                                  if (ok) {
                                    _make.clear();
                                    _model.clear();
                                    _plate.clear();
                                    _category.clear();
                                  }
                                  return ok;
                                }),
                          child: const Text('Add vehicle'),
                        ),
                      ],
                    ] else if (rule != null) ...[
                      GuidedDocumentCapture(
                        key: ValueKey(
                          '${_vehicleId ?? 'business'}:${rule.code}',
                        ),
                        rule: rule,
                        picker: widget.picker,
                        scope: '${a.api.userId}:${_vehicleId ?? 'business'}',
                        onBusyChanged: (v) {
                          if (mounted) setState(() => _choosing = v);
                        },
                        draft: _drafts.putIfAbsent(
                          '${_vehicleId ?? 'business'}:${rule.code}',
                          () {
                            final draft = CaptureDraft();
                            context
                                    .read<DriverSession>()
                                    .onboardingDrafts['provider:${_vehicleId ?? 'business'}:${rule.code}'] =
                                draft;
                            return draft;
                          },
                        ),
                        disabled: busy,
                        changed: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => act(() async {
                                if (a.refreshWarning != null) {
                                  return a.refresh();
                                }
                                final draft =
                                    _drafts['${_vehicleId ?? 'business'}:${rule.code}']!;
                                final metadata = {
                                  'uploadSource': draft.source,
                                  if (draft.expiry.trim().isNotEmpty)
                                    'expiresAt': draft.expiry.trim(),
                                  if (draft.number.trim().isNotEmpty)
                                    'documentNumber': draft.number.trim(),
                                };
                                final imageError = await validateCaptureDraft(
                                  rule,
                                  draft,
                                );
                                if (imageError != null) {
                                  _error = imageError;
                                  return false;
                                }
                                final validation =
                                    OnboardingRules.validateFiles(
                                      rule,
                                      draft.files,
                                      metadata,
                                    );
                                if (validation != null) {
                                  _error = validation;
                                  return false;
                                }
                                final ok = await a.uploadDocument(
                                  rule,
                                  draft.files,
                                  metadata,
                                  vehicleId: vehicle ? _vehicleId : null,
                                );
                                if (ok) draft.files.clear();
                                return ok;
                              }),
                        child: const Text('Upload & continue'),
                      ),
                    ] else ...[
                      Text(
                        'Status: ${statusLabel(reviewEntity?['verificationStatus'] ?? reviewEntity?['approvalStatus'])}',
                      ),
                      for (final r in required)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(r.label),
                          subtitle: Text(
                            statusLabel(
                              a.documentFor(
                                r.code,
                                vehicleId: vehicle ? _vehicleId : null,
                              )?['status'],
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => act(
                                () => a.requestReview(
                                  vehicle ? 'vehicle' : 'partner',
                                  vehicle
                                      ? _vehicleId!
                                      : a.partner!['id'] as String,
                                  vehicle
                                      ? 'vehicle_verification'
                                      : 'fleet_verification',
                                ),
                              ),
                        child: const Text('Request review'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => act(a.refresh),
                        child: const Text('Refresh decision'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => _task = 'vehicle'),
                        child: const Text('Continue to owned vehicles'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => _task = 'business'),
                        child: const Text('Edit business information'),
                      ),
                    ],
                    if (_error != null || a.error != null)
                      Text(
                        _error ?? a.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (busy) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
    );
  }
}

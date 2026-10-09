import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import 'document_upload_dialog.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key});
  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _fields = <String, TextEditingController>{};
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _code = TextEditingController();
  final _partner = TextEditingController();
  final _category = TextEditingController();
  String _sector = 'passenger';
  int _step = 0;
  bool _initialized = false;
  static const _labels = {
    'licenseNumber': 'Driving licence number *',
    'licenseExpiry': 'Licence expiry (YYYY-MM-DD) *',
    'dob': 'Date of birth (YYYY-MM-DD)',
    'gender': 'Gender',
    'address': 'Address',
    'city': 'City',
    'state': 'State',
    'pinCode': 'Postal code',
    'emergencyContactName': 'Emergency contact name',
    'emergencyContactPhone': 'Emergency contact phone',
    'emergencyContactRelationship': 'Relationship',
    'alternateContactPhone': 'Alternate phone',
  };
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _firstName.dispose();
    _lastName.dispose();
    _code.dispose();
    _partner.dispose();
    _category.dispose();
    super.dispose();
  }

  Widget _documents(DriverSession session, bool vehicle) {
    final all = <String, DocumentRule>{
      for (final rule in session.documentRules) rule.code: rule,
    };
    for (final code in [
      'profile_photo',
      'driver_license',
      'vehicle_rc',
      'identity',
      'pan',
      'other',
    ]) {
      all.putIfAbsent(code, () => DocumentRule(code));
    }
    // Keep correction available when a previously uploaded document's policy is removed.
    for (final document in session.documents) {
      final code =
          (document['documentMetadata'] as Map?)?['documentCode'] ??
          document['documentType'];
      if (code is String) all.putIfAbsent(code, () => DocumentRule(code));
    }
    bool vehicleDocument(DocumentRule rule) =>
        rule.code.startsWith('vehicle_') ||
        ['insurance', 'permit', 'fitness', 'rc'].contains(rule.code);
    final shown = all.values
        .where((rule) => vehicleDocument(rule) == vehicle)
        .toList();
    return Column(
      children: [
        Text(
          vehicle
              ? 'Vehicle documents are determined by the assigned or previewed vehicle category.'
              : 'Required documents come from the production document policy. Other supported documents are optional.',
        ),
        for (final rule in shown)
          Card(
            child: ListTile(
              title: Text(
                '${rule.label}${rule.required ? ' *' : ' (optional)'}',
              ),
              subtitle: Text(
                "${statusLabel(OnboardingRules.documentFor(rule.code, session.documents)?['verificationStatus'])}\n${OnboardingRules.documentFor(rule.code, session.documents) == null ? '' : rejectionReason(OnboardingRules.documentFor(rule.code, session.documents)!) ?? ''}",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: session.busy || session.profile == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            DocumentUploadDialog(session: session, rule: rule),
                      ),
              ),
            ),
          ),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No vehicle document requirements are configured for this category.',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    if (!session.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_initialized && session.onboardingLoaded) {
      for (final key in _labels.keys) {
        _fields[key] = TextEditingController(
          text: session.profile?[key]?.toString() ?? '',
        );
      }
      _firstName.text = session.account?['firstName']?.toString() ?? '';
      _lastName.text = session.account?['lastName']?.toString() ?? '';
      _step = _firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty
          ? 0
          : session.profile == null
          ? 1
          : session.missingUploads.isNotEmpty
          ? 2
          : session.assignedVehicle == null
          ? 3
          : 5;
      _initialized = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver onboarding'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              TextButton(
                onPressed: session.busy
                    ? null
                    : () => context.go('/provider-assets'),
                child: const Text('Owned vehicle / provider profile'),
              ),
              if (session.api.hasFleetRole)
                TextButton(
                  onPressed: session.busy
                      ? null
                      : () async {
                          final ok = await session.switchMode('fleet_owner');
                          if (context.mounted && ok) {
                            context.go(session.landingPath);
                          }
                        },
                  child: const Text('Fleet mode'),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: session.busy
                ? null
                : () async {
                    await session.logout();
                    if (context.mounted) context.go('/login');
                  },
          ),
          IconButton(
            onPressed: session.busy ? null : session.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !session.onboardingLoaded
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.error ?? 'Loading your onboarding requirements…',
                  ),
                  TextButton(
                    onPressed: session.busy ? null : session.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (session.error != null)
                  Text(
                    session.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                Stepper(
                  physics: const NeverScrollableScrollPhysics(),
                  currentStep: _step,
                  onStepTapped: session.busy
                      ? null
                      : (i) => setState(() => _step = i),
                  onStepContinue: session.busy
                      ? null
                      : () async {
                          if (_step == 0) {
                            final ok = await session.saveAccountNames(
                              _firstName.text,
                              _lastName.text,
                            );
                            if (!ok || !mounted) return;
                          }
                          if (_step == 1) {
                            final ok = await session.saveProfile({
                              for (final entry in _fields.entries)
                                if (entry.value.text.trim().isNotEmpty)
                                  entry.key: entry.value.text.trim(),
                            });
                            if (!ok || !mounted) return;
                          }
                          if (_step == 5) {
                            final ok = await session.submitOnboarding();
                            if (ok && context.mounted) {
                              context.go('/verification-status');
                            }
                            return;
                          }
                          setState(() => _step++);
                        },
                  onStepCancel: _step == 0 || session.busy
                      ? null
                      : () => setState(() => _step--),
                  controlsBuilder: (context, details) => Row(
                    children: [
                      FilledButton(
                        onPressed: details.onStepContinue,
                        child: Text(
                          _step == 5
                              ? 'Submit for verification'
                              : _step == 1
                              ? 'Save & continue'
                              : 'Continue',
                        ),
                      ),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                  steps: [
                    Step(
                      title: const Text('Account information'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _firstName,
                            enabled: !session.busy,
                            decoration: const InputDecoration(
                              labelText: 'First name *',
                            ),
                          ),
                          TextField(
                            controller: _lastName,
                            enabled: !session.busy,
                            decoration: const InputDecoration(
                              labelText: 'Last name *',
                            ),
                          ),
                          Text(session.account?['email']?.toString() ?? ''),
                          Text(session.account?['phone']?.toString() ?? ''),
                          const Text(
                            'Account authenticated. Driver approval is reviewed separately.',
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Personal details & licence'),
                      content: Column(
                        children: [
                          const Text(
                            'Only licence number and expiry are mandatory here. Other personal details are optional.',
                          ),
                          for (final entry in _labels.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: TextField(
                                controller: _fields[entry.key],
                                enabled: !session.busy,
                                decoration: InputDecoration(
                                  labelText: entry.value,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('KYC & driver documents'),
                      content: _documents(session, false),
                    ),
                    Step(
                      title: const Text('Vehicle association'),
                      content: Column(
                        children: [
                          if (session.assignedVehicle != null)
                            Text(
                              'Assigned vehicle: ${session.assignedVehicle!['plateNumber']} • ${session.assignedVehicle!['make']} ${session.assignedVehicle!['model']}',
                            ),
                          const Text(
                            'Your fleet manages vehicle registration and approval. Driver approval and active fleet membership are required before claiming an assignment.',
                          ),
                          TextField(
                            controller: _code,
                            maxLength: 20,
                            decoration: const InputDecoration(
                              labelText: 'Fleet assignment code',
                            ),
                          ),
                          TextButton(
                            onPressed: session.busy
                                ? null
                                : () => session.previewAssignment(_code.text),
                            child: const Text(
                              'Check vehicle & document policy',
                            ),
                          ),
                          if (session.assignmentPreview != null)
                            Text(
                              'Vehicle: ${session.assignmentPreview!['vehicle']['plateNumber']} • ${session.assignmentPreview!['vehicle']['category']}',
                            ),
                          FilledButton(
                            onPressed:
                                session.busy ||
                                    session.profile?['verificationStatus'] !=
                                        'approved' ||
                                    session.assignmentPreview == null
                                ? null
                                : () => session.claimAssignment(_code.text),
                            child: const Text('Claim approved assignment'),
                          ),
                          const Divider(),
                          const Text(
                            'Apply to a fleet using the partner reference supplied by that fleet. This is separate from the vehicle assignment code.',
                          ),
                          TextField(
                            controller: _partner,
                            decoration: const InputDecoration(
                              labelText: 'Fleet partner reference (UUID)',
                            ),
                          ),
                          DropdownButton<String>(
                            value: _sector,
                            isExpanded: true,
                            items: [
                              for (final v in [
                                'passenger',
                                'logistics',
                                'service',
                                'premium',
                                'rental',
                              ])
                                DropdownMenuItem(value: v, child: Text(v)),
                            ],
                            onChanged: session.busy
                                ? null
                                : (v) => setState(() => _sector = v!),
                          ),
                          TextField(
                            controller: _category,
                            decoration: const InputDecoration(
                              labelText: 'Requested vehicle category supplied by fleet',
                            ),
                          ),
                          TextButton(
                            onPressed: session.busy || session.profile == null
                                ? null
                                : () => session.applyToFleet({
                                    'partnerId': _partner.text.trim(),
                                    'requestedSector': _sector,
                                    'requestedVehicleCategory': _category.text
                                        .trim(),
                                  }),
                            child: const Text('Submit fleet application'),
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Vehicle documents'),
                      content: Column(
                        children: [
                          const Text(
                            'Owned vehicle documents must be associated with the vehicle and provider profile. Fleet-owned documents are managed by the Fleet Owner.',
                          ),
                          TextButton(
                            onPressed: () => context.go('/provider-assets'),
                            child: const Text('Manage owned vehicle documents'),
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('Review & submit'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Driver profile: ${session.profile?['verificationStatus'] ?? 'Not saved'}',
                          ),
                          Text(
                            'Documents uploaded: ${session.documents.length}',
                          ),
                          Text(
                            'Missing required uploads: ${session.missingUploads.isEmpty ? 'None' : session.missingUploads.map((r) => r.label).join(', ')}',
                          ),
                          const Text(
                            'Submission requests backend review. It does not approve your profile or documents. You can submit driver verification before vehicle assignment.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/verification-status'),
                  child: const Text('View verification status'),
                ),
                TextButton(
                  onPressed: session.busy
                      ? null
                      : () async {
                          await session.logout();
                          if (context.mounted) context.go('/login');
                        },
                  child: const Text('Sign out'),
                ),
              ],
            ),
    );
  }
}

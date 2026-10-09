import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../providers/provider_assets.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import '../auth/document_upload_dialog.dart';

class ProviderAssetsScreen extends StatefulWidget {
  const ProviderAssetsScreen({super.key});
  @override
  State<ProviderAssetsScreen> createState() => _ProviderAssetsScreenState();
}

class _ProviderAssetsScreenState extends State<ProviderAssetsScreen> {
  ProviderAssets? _assets;
  Timer? _timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assets == null) {
      _assets = ProviderAssets(context.read<DriverSession>().api)
        ..addListener(_changed);
      unawaited(_assets!.refresh());
      _timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (context.read<DriverSession>().authenticated) {
          unawaited(_assets!.refresh());
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _assets?.removeListener(_changed);
    _assets?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _form(
    String title,
    Map<String, String> labels, {
    Map<String, dynamic>? initial,
    Set<String> requiredFields = const {},
    Set<String> numbers = const {},
    Set<String> integers = const {},
    Set<String> booleans = const {},
  }) async {
    final fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: initial?[key]?.toString() ?? ''),
    };
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in labels.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextFormField(
                        controller: fields[e.key],
                        keyboardType:
                            numbers.contains(e.key) || integers.contains(e.key)
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: e.value),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (requiredFields.contains(e.key) && text.isEmpty) {
                            return 'Required';
                          }
                          if (booleans.contains(e.key) &&
                              !['true', 'false'].contains(text)) {
                            return 'Enter true or false';
                          }
                          if (text.isNotEmpty &&
                              numbers.contains(e.key) &&
                              (double.tryParse(text) == null ||
                                  !double.parse(text).isFinite ||
                                  double.parse(text) < 0)) {
                            return 'Enter a nonnegative number';
                          }
                          if (text.isNotEmpty &&
                              integers.contains(e.key) &&
                              int.tryParse(text) == null) {
                            return 'Enter a whole number';
                          }
                          if (text.isNotEmpty &&
                              (e.key.contains('Date') ||
                                  e.key.contains('Expiry')) &&
                              !OnboardingRules.validDate(text)) {
                            return 'Use YYYY-MM-DD';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, <String, dynamic>{
                for (final e in fields.entries)
                  if (e.value.text.trim().isNotEmpty)
                    e.key: booleans.contains(e.key)
                        ? e.value.text.trim() == 'true'
                        : numbers.contains(e.key)
                        ? double.parse(e.value.text.trim())
                        : integers.contains(e.key)
                        ? int.parse(e.value.text.trim())
                        : e.value.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dispose after the closing animation releases TextField listeners.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final c in fields.values) {
        c.dispose();
      }
    });
    return result;
  }

  Future<void> _business() async {
    final input = await _form(
      'Provider / business information',
      const {
        'businessName': 'Business / provider name *',
        'businessType': 'Business type (optional)',
        'gstNumber': 'GST number (optional)',
        'ownerName': 'Owner name (optional)',
        'businessDescription': 'Description (optional)',
        'address': 'Address (optional)',
        'city': 'City (optional)',
        'state': 'State (optional)',
        'pinCode': 'Postal code (optional)',
        'numberOfVehicles': 'Number of vehicles (optional)',
      },
      initial: _assets!.partner,
      requiredFields: {'businessName'},
      integers: {'numberOfVehicles'},
    );
    if (input != null) await _assets!.saveBusiness(input);
  }

  Future<void> _vehicle([Map<String, dynamic>? vehicle]) async {
    final input = await _form(
      vehicle == null ? 'Add owned vehicle' : 'Edit vehicle',
      const {
        'make': 'Make *',
        'model': 'Model *',
        'plateNumber': 'Registration / plate number *',
        'sector': 'Sector: passenger, logistics, service or premium',
        'category': 'Vehicle category',
        'color': 'Color (optional)',
        'fuelType': 'Fuel type (optional)',
        'fuelRatePerKm': 'Fuel cost / km (optional)',
        'loadCapacityKg': 'Load capacity kg (optional)',
        'year': 'Manufacturing year (1990–2035, optional)',
        'seatingCapacity': 'Seats (1–100, optional)',
        'registrationDate': 'Registration date (optional, YYYY-MM-DD)',
        'registrationExpiry': 'Registration expiry (optional, YYYY-MM-DD)',
        'permitDetails': 'Commercial permit details (optional)',
        'isCommercial': 'Commercial vehicle (true / false)',
      },
      initial: {'isCommercial': true, ...?vehicle},
      requiredFields: {'make', 'model', 'plateNumber'},
      numbers: {'fuelRatePerKm', 'loadCapacityKg'},
      integers: {'year', 'seatingCapacity'},
      booleans: {'isCommercial'},
    );
    if (input != null) {
      await _assets!.saveVehicle(input, id: vehicle?['id'] as String?);
    }
  }

  Widget _review(String type, String id, String requestType) => TextButton(
    onPressed: _assets!.busy
        ? null
        : () => _assets!.requestReview(type, id, requestType),
    child: const Text('Request verification'),
  );
  Future<void> _upload(DocumentRule rule, {String? vehicleId}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DocumentUploadDialog(
          session: context.read<DriverSession>(),
          rule: rule,
          uploader: (rule, files, metadata) => _assets!.uploadDocument(
            rule,
            files,
            metadata,
            vehicleId: vehicleId,
          ),
          errorMessage: () => _assets!.error,
        ),
      );
  Widget _document(DocumentRule rule, {String? vehicleId}) {
    final doc = _assets!.documentFor(rule.code, vehicleId: vehicleId);
    final reason = doc == null ? null : rejectionReason(doc);
    return Card(
      child: ListTile(
        title: Text(
          '${rule.label} — ${rule.required ? 'Required by policy' : 'Optional'}',
        ),
        subtitle: Text(
          '${statusLabel(doc?['status'])}\n${rule.minimumPages}–5 files/pages; JPEG, PNG, WebP${rule.code == 'profile_photo' ? '' : ', PDF'}; ${rule.code == 'profile_photo' ? 10 : 15} MiB/file, 30 MiB total\nExpiry ${rule.requiresExpiry ? 'required' : 'optional'}${reason == null ? '' : '\nReason: $reason'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: doc == null ? 'Upload' : 'Replace / resubmit',
          icon: const Icon(Icons.upload_file),
          onPressed: _assets!.busy || _assets!.partner == null
              ? null
              : () => _upload(rule, vehicleId: vehicleId),
        ),
      ),
    );
  }

  Future<void> _vehicleDocuments(Map<String, dynamic> vehicle) async {
    List<DocumentRule> policy = [];
    final ok = await _assets!.run(() async {
      policy = await _assets!.vehicleRules(vehicle);
    });
    if (!mounted || !ok) return;
    final rules = <String, DocumentRule>{
      for (final rule in policy.where((r) => r.code.startsWith('vehicle_')))
        rule.code: rule,
    };
    for (final code in [
      'vehicle_rc',
      'vehicle_insurance',
      'vehicle_permit',
      'vehicle_fitness',
      'vehicle_puc',
      'other',
    ]) {
      rules.putIfAbsent(code, () => DocumentRule(code));
    }
    // Arbitrary configured codes can be attached to this vehicle, without inventing a document policy.
    for (final rule in policy) {
      rules.putIfAbsent(rule.code, () => rule);
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Documents: ${vehicle['plateNumber']}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final rule in rules.values)
                  _document(rule, vehicleId: vehicle['id'] as String),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>(), assets = _assets!;
    if (!session.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final rules = <String, DocumentRule>{
      for (final r in assets.rules.where((r) => !r.code.startsWith('vehicle_')))
        r.code: r,
    };
    for (final code in [
      'aadhaar',
      'pan',
      'driving_licence',
      'profile_photo',
      'address_proof',
      'other',
    ]) {
      rules.putIfAbsent(code, () => DocumentRule(code));
    }
    for (final document in assets.documents.where(
      (d) => d['vehicleId'] == null,
    )) {
      final code =
          ((document['metadata'] as Map?)?['documentCode'] ??
                  document['documentType'].toString().toLowerCase())
              .toString();
      rules.putIfAbsent(code, () => DocumentRule(code));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          assets.fleetMode
              ? (assets.partner == null ||
                        assets.partner?['approvalStatus'] != 'approved'
                    ? 'Fleet onboarding & verification'
                    : 'Fleet account & operations')
              : 'Owned vehicle & provider profile',
        ),
        actions: [
          IconButton(
            onPressed: assets.busy ? null : assets.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: session.busy
                ? null
                : () async {
                    await session.logout();
                    if (context.mounted) context.go('/login');
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (assets.busy) const LinearProgressIndicator(),
          if (assets.error != null)
            Text(assets.error!, style: const TextStyle(color: Colors.red)),
          if (session.api.role == 'driver_fleet_owner')
            TextButton(
              onPressed: session.busy
                  ? null
                  : () async {
                      final ok = await session.switchMode(
                        assets.fleetMode ? 'driver' : 'fleet_owner',
                      );
                      if (context.mounted && ok) {
                        context.go(session.landingPath);
                      }
                    },
              child: Text(
                assets.fleetMode
                    ? 'Switch to Driver mode'
                    : 'Switch to Fleet mode',
              ),
            ),
          if (!assets.fleetMode)
            TextButton(
              onPressed: () => context.go(session.landingPath),
              child: const Text('Back to Driver onboarding / dashboard'),
            ),
          Text(
            'Provider profile: ${statusLabel(assets.partner?['approvalStatus'])}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (assets.partner != null) ...[
            Text(assets.partner!['businessName']?.toString() ?? ''),
            SelectableText('Partner reference: ${assets.partner!['id']}'),
            if (rejectionReason(assets.partner!) != null)
              Text(rejectionReason(assets.partner!)!),
          ],
          OutlinedButton(
            onPressed: assets.busy ? null : _business,
            child: Text(
              assets.partner == null
                  ? 'Create provider / business profile'
                  : 'Correct provider / business details',
            ),
          ),
          if (assets.partner == null)
            const Text(
              'Complete your business details first, then upload the documents required by the active policy. Backend review is required before approval.',
            ),
          if (assets.partner != null)
            _review(
              'partner',
              assets.partner!['id'] as String,
              'fleet_verification',
            ),
          ExpansionTile(
            title: const Text('Provider documents'),
            children: [for (final r in rules.values) _document(r)],
          ),
          const Divider(),
          Text('Owned vehicles', style: Theme.of(context).textTheme.titleLarge),
          if (!assets.approvedPartner)
            const Text(
              'Backend partner approval is required before managing owned vehicles.',
            ),
          FilledButton(
            onPressed: assets.busy || !assets.approvedPartner ? null : _vehicle,
            child: const Text('Add vehicle'),
          ),
          for (final v in assets.vehicles)
            Card(
              child: ExpansionTile(
                title: Text('${v['plateNumber']} • ${v['make']} ${v['model']}'),
                subtitle: Text(
                  '${statusLabel(v['verificationStatus'])} • ${v['operationalStatus'] ?? 'INACTIVE'}',
                ),
                children: [
                  if (rejectionReason(v) != null) Text(rejectionReason(v)!),
                  TextButton(
                    onPressed: assets.busy ? null : () => _vehicle(v),
                    child: const Text('Edit vehicle'),
                  ),
                  TextButton(
                    onPressed: assets.busy ? null : () => _vehicleDocuments(v),
                    child: const Text('Vehicle documents'),
                  ),
                  _review('vehicle', v['id'] as String, 'vehicle_verification'),
                  if (!assets.fleetMode) ...[
                    Wrap(
                      children: [
                        for (final state in [
                          'ACTIVE',
                          'INACTIVE',
                          'MAINTENANCE',
                        ])
                          TextButton(
                            onPressed: assets.busy
                                ? null
                                : () =>
                                      assets.operate(v['id'] as String, state),
                            child: Text(state),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: assets.busy || session.profile == null
                          ? null
                          : () async {
                              final ok = await session.run(() async {
                                await session.api.request(
                                  'POST',
                                  '/rides/driver/active-vehicle',
                                  body: {'vehicleId': v['id']},
                                );
                              });
                              if (ok) await session.refresh();
                            },
                      child: const Text('Select own approved vehicle'),
                    ),
                  ],
                  if (assets.fleetMode) ...[
                    Wrap(
                      children: [
                        for (final state in [
                          'ACTIVE',
                          'INACTIVE',
                          'MAINTENANCE',
                        ])
                          TextButton(
                            onPressed: assets.busy
                                ? null
                                : () =>
                                      assets.operate(v['id'] as String, state),
                            child: Text(state),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: assets.busy
                          ? null
                          : () async {
                              final code = await assets.assignmentCode(
                                v['id'] as String,
                              );
                              if (context.mounted && code != null) {
                                showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Fleet assignment code'),
                                    content: SelectableText(
                                      '${code['code']}\nExpires: ${code['expiresAt']}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                      child: const Text('Generate assignment code'),
                    ),
                    TextButton(
                      onPressed: assets.busy
                          ? null
                          : () => assets.unassign(v['id'] as String),
                      child: const Text('Unassign driver'),
                    ),
                  ],
                ],
              ),
            ),
          if (assets.fleetMode) ...[
            ExpansionTile(
              title: const Text('Fleet driver memberships'),
              children: [
                if (assets.drivers.isEmpty)
                  const ListTile(title: Text('No driver memberships')),
                for (final d in assets.drivers)
                  ListTile(
                    title: Text(d['name']?.toString() ?? 'Driver'),
                    subtitle: Text(
                      '${d['status'] ?? d['membershipStatus'] ?? ''} • ${d['availabilityStatus'] ?? ''}',
                    ),
                    trailing: TextButton(
                      onPressed: assets.busy
                          ? null
                          : () => assets.deactivateMembership(
                              (d['driverProfileId'] ?? d['id']) as String,
                            ),
                      child: const Text('Deactivate membership'),
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Live fleet location'),
              children: [
                if (assets.tracking.isEmpty)
                  const ListTile(title: Text('No location records')),
                for (final d in assets.tracking)
                  ListTile(
                    title: Text(d['plateNumber']?.toString() ?? 'Driver'),
                    subtitle: Text(
                      '${d['latitude'] ?? 'Unknown'}, ${d['longitude'] ?? 'Unknown'}\nRecorded: ${d['recordedAt'] ?? 'Unknown'} • ${d['stale'] == true ? 'Stale' : 'Recent'}',
                    ),
                  ),
              ],
            ),
          ],
          ExpansionTile(
            title: const Text('Verification requests'),
            children: [
              for (final a in assets.approvals)
                ListTile(
                  title: Text(
                    (a['request_type'] ?? a['requestType']).toString(),
                  ),
                  subtitle: Text(
                    '${statusLabel(a['status'])}\n${a['rejection_reason'] ?? a['rejectionReason'] ?? ''}',
                  ),
                ),
            ],
          ),
          ExpansionTile(
            title: const Text('Backend settlement ledger'),
            children: [
              for (final row in assets.earnings?['periods'] as List? ?? [])
                ListTile(
                  title: Text(row['period'].toString()),
                  subtitle: Text(
                    'Gross ₹${(double.tryParse(row['grossPaise'].toString()) ?? 0) / 100} • Commission ₹${(double.tryParse(row['commissionPaise'].toString()) ?? 0) / 100} • Net ₹${(double.tryParse(row['netPaise'].toString()) ?? 0) / 100}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

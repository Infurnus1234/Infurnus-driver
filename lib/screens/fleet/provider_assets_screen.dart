import 'fleet_revenue_screen.dart';
import 'fleet_vehicle_category_dialog.dart';
import '../../widgets/calendar_field.dart';
import 'managed_driver_screen.dart';

import '../../widgets/private_document_preview.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/fleet_model_field.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../providers/provider_assets.dart';
import '../../models/onboarding_rules.dart';
import '../../models/provider_status.dart';
import '../../widgets/fleet_overview.dart';
import '../../widgets/operations.dart';
import '../../widgets/reference_components.dart';
import '../../core/operations_theme.dart';
import '../auth/document_upload_dialog.dart';
import 'guided_provider_setup.dart';

class ProviderAssetsScreen extends StatefulWidget {
  final bool identityOnly, bankProofOnly;
  const ProviderAssetsScreen({
    super.key,
    this.identityOnly = false,
    this.bankProofOnly = false,
  });
  @override
  State<ProviderAssetsScreen> createState() => _ProviderAssetsScreenState();
}

class _ProviderAssetsScreenState extends State<ProviderAssetsScreen> {
  ProviderAssets? _assets;
  Timer? _timer;
  String _search = '';
  int _tab = 0;
  @override
  void initState() {
    super.initState();
    if (widget.identityOnly || widget.bankProofOnly) _tab = 4;
  }

  String _vehicleFilter = 'All';
  bool _guidedSetup = false;
  bool _matches(Map row) =>
      _search.isEmpty ||
      row.values.any(
        (value) => value.toString().toLowerCase().contains(_search),
      );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assets == null) {
      _assets = ProviderAssets(context.read<DriverSession>().api)
        ..addListener(_changed);
      unawaited(_assets!.refresh());
      _timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (context.read<DriverSession>().authenticated && !_guidedSetup) {
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
    Future<bool> Function(Map<String, dynamic>)? onSubmit,
  }) async {
    final fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: initial?[key]?.toString() ?? ''),
    };
    final form = GlobalKey<FormState>();
    final primary = {
      ...requiredFields,
      if (labels.containsKey('sector')) 'sector',
      if (labels.containsKey('category')) 'category',
    };
    bool optionalOpen = false;
    bool submitting = false;
    String? submitError;
    String? validate(String key, String? value) {
      final text = value?.trim() ?? '';
      if (key == 'ownershipType' &&
          text.isNotEmpty &&
          !['OWNED', 'LEASED', 'FINANCED', 'OTHER'].contains(text)) {
        return 'Choose OWNED, LEASED, FINANCED or OTHER';
      }
      if (requiredFields.contains(key) && text.isEmpty) return 'Required';
      if (booleans.contains(key) && !['true', 'false'].contains(text)) {
        return 'Choose true or false';
      }
      if (text.isNotEmpty &&
          numbers.contains(key) &&
          (double.tryParse(text) == null ||
              !double.parse(text).isFinite ||
              double.parse(text) < 0)) {
        return 'Enter a nonnegative number';
      }
      if (text.isNotEmpty &&
          integers.contains(key) &&
          int.tryParse(text) == null) {
        return 'Enter a whole number';
      }
      if (text.isNotEmpty &&
          (key.contains('Date') || key.contains('Expiry')) &&
          !OnboardingRules.validDate(text)) {
        return 'Use YYYY-MM-DD';
      }
      if (key == 'registrationExpiry' &&
          text.isNotEmpty &&
          fields['registrationDate']!.text.isNotEmpty &&
          text.compareTo(fields['registrationDate']!.text) < 0) {
        return 'Expiry must follow registration date';
      }
      return null;
    }

    Widget field(MapEntry<String, String> entry) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: entry.key == 'sector'
          ? DropdownButtonFormField<String>(
              initialValue: fields[entry.key]!.text.isEmpty
                  ? null
                  : fields[entry.key]!.text,
              decoration: const InputDecoration(labelText: 'Sector'),
              items: [
                'passenger',
                'logistics',
                'service',
                'premium',
                if (fields[entry.key]!.text.isNotEmpty &&
                    ![
                      'passenger',
                      'logistics',
                      'service',
                      'premium',
                    ].contains(fields[entry.key]!.text))
                  fields[entry.key]!.text,
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) => fields[entry.key]!.text = value ?? '',
              validator: (v) => validate(entry.key, v),
            )
          : booleans.contains(entry.key)
          ? DropdownButtonFormField<String>(
              initialValue: ['true', 'false'].contains(fields[entry.key]!.text)
                  ? fields[entry.key]!.text
                  : null,
              decoration: InputDecoration(labelText: entry.value),
              items: const [
                DropdownMenuItem(value: 'true', child: Text('Yes')),
                DropdownMenuItem(value: 'false', child: Text('No')),
              ],
              onChanged: (v) => fields[entry.key]!.text = v ?? '',
              validator: (v) => validate(entry.key, v),
            )
          : entry.key.contains('Date') || entry.key.contains('Expiry')
          ? CalendarField(
              label: entry.value,
              controller: fields[entry.key],
              validator: (v) => validate(entry.key, v),
            )
          : entry.key == 'model' && fields.containsKey('make')
          ? FleetModelField(
              api: context.read<DriverSession>().api,
              make: fields['make']!,
              model: fields['model']!,
            )
          : TextFormField(
              controller: fields[entry.key],
              keyboardType:
                  numbers.contains(entry.key) || integers.contains(entry.key)
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(labelText: entry.value),
              validator: (v) => validate(entry.key, v),
            ),
    );
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, update) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (submitting) const LinearProgressIndicator(),
                      if (submitError != null)
                        Text(
                          submitError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (labels.containsKey('plateNumber')) ...[
                        const Icon(
                          Icons.directions_car_outlined,
                          color: Ops.success,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vehicle details',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Save the vehicle details, then add its documents for review.',
                          style: TextStyle(color: Ops.textSecondary),
                        ),
                        const SizedBox(height: 24),
                      ],
                      for (final entry in labels.entries.where(
                        (e) => primary.contains(e.key),
                      ))
                        field(entry),
                      if (labels.keys.any((key) => !primary.contains(key)))
                        ExpansionTile(
                          key: ValueKey(optionalOpen),
                          initiallyExpanded: optionalOpen,
                          maintainState: true,
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Optional details'),
                          onExpansionChanged: (v) => optionalOpen = v,
                          children: [
                            for (final entry in labels.entries.where(
                              (e) => !primary.contains(e.key),
                            ))
                              field(entry),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: Ops.darkButton,
                        onPressed: submitting
                            ? null
                            : () async {
                                final invalidOptional = fields.entries.any(
                                  (e) =>
                                      !primary.contains(e.key) &&
                                      validate(e.key, e.value.text) != null,
                                );
                                if (invalidOptional) {
                                  update(() => optionalOpen = true);
                                }
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => form.currentState?.validate(),
                                );
                                if (!form.currentState!.validate() ||
                                    invalidOptional) {
                                  return;
                                }
                                final values = <String, dynamic>{
                                  for (final entry in fields.entries)
                                    if (entry.value.text.trim().isNotEmpty)
                                      entry.key: booleans.contains(entry.key)
                                          ? entry.value.text.trim() == 'true'
                                          : numbers.contains(entry.key)
                                          ? double.parse(
                                              entry.value.text.trim(),
                                            )
                                          : integers.contains(entry.key)
                                          ? int.parse(entry.value.text.trim())
                                          : entry.value.text.trim(),
                                };
                                if (onSubmit != null) {
                                  update(() {
                                    submitting = true;
                                    submitError = null;
                                  });
                                  final ok = await onSubmit(values);
                                  if (!context.mounted) return;
                                  if (!ok) {
                                    update(() {
                                      submitting = false;
                                      submitError = _assets!.error ?? 'Could not save. Your entries are retained; retry.';
                                    });
                                    return;
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.pop(context, values);
                                }
                              },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    final category = await selectFleetVehicleCategory(
      context,
      context.read<DriverSession>().api,
      initial: vehicle,
    );
    if (!mounted || category == null) return;
    final input = await _form(
      vehicle == null ? 'Add owned vehicle' : 'Edit vehicle',
      const {
        'make': 'Make *',
        'model': 'Model *',
        'plateNumber': 'Registration / plate number *',
        'color': 'Color (optional)',
        'fuelType': 'Fuel type (optional)',
        'fuelRatePerKm': 'Fuel cost / km (optional)',
        'loadCapacityKg': 'Load capacity kg (optional)',
        'year': 'Manufacturing year (1990–2035, optional)',
        'seatingCapacity': 'Seats (1–100, optional)',
        'registrationDate': 'Registration date (optional, YYYY-MM-DD)',
        'registrationExpiry': 'Registration expiry (optional, YYYY-MM-DD)',
        'permitDetails': 'Commercial permit details (optional)',
        'ownershipType': 'Ownership: OWNED, LEASED, FINANCED or OTHER',
        'ownerNotes': 'Vehicle notes (optional)',
        'isCommercial': 'Commercial vehicle (true / false)',
      },
      initial: {'isCommercial': true, ...?vehicle},
      requiredFields: {'make', 'model', 'plateNumber'},
      numbers: {'fuelRatePerKm', 'loadCapacityKg'},
      integers: {'year', 'seatingCapacity'},
      booleans: {'isCommercial'},
      onSubmit: (values) => _assets!.saveVehicle({
        ...values,
        ...category,
      }, id: vehicle?['id'] as String?),
    );
    if (input != null) {
      if (vehicle == null && mounted) {
        final saved = _assets!.vehicles
            .where(
              (v) =>
                  v['plateNumber'].toString().toUpperCase() ==
                  input['plateNumber'].toString().toUpperCase(),
            )
            .firstOrNull;
        if (saved?['activeAssignmentCode'] != null) {
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('Vehicle saved · ${saved!['plateNumber']}'),
              content: SelectableText(
                'Vehicle joining code: ${saved['activeAssignmentCode']}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      }
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
    final expiry = DateTime.tryParse(doc?['expiresAt']?.toString() ?? '');
    final expired =
        expiry != null &&
        expiry.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final soon =
        expiry != null &&
        !expired &&
        expiry.isBefore(DateTime.now().add(const Duration(days: 30)));
    return Card(
      child: ListTile(
        onTap: doc == null || _assets!.busy
            ? null
            : () => showPrivateDocumentPreview(
                context,
                _assets!.api,
                '/partners/${_assets!.partner!['id']}/documents/${doc['id']}',
                rule.label,
              ),
        title: Text(
          '${rule.label} — ${rule.required ? 'Required by policy' : 'Optional'}',
        ),
        subtitle: Text(
          '${expired ? 'Expired' : statusLabel(doc?['status'])}${soon ? ' — expires within 30 days' : ''}${expiry == null ? '' : '\nExpiry: ${doc!['expiresAt']}'}\n${rule.minimumPages}–5 files/pages; JPEG, PNG, WebP${rule.code == 'profile_photo' ? '' : ', PDF'}; ${rule.code == 'profile_photo' ? 10 : 15} MiB/file, 30 MiB total\nExpiry ${rule.requiresExpiry ? 'required' : 'optional'}${reason == null ? '' : '\nReason: $reason'}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: doc == null ? 'Upload' : 'Replace / resubmit',
              icon: const Icon(Icons.upload_file),
              onPressed: _assets!.busy
                  ? null
                  : () {
                      if (_assets!.partner == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please create your provider/business profile first.',
                            ),
                          ),
                        );
                        _business();
                        return;
                      }
                      _upload(rule, vehicleId: vehicleId);
                    },
            ),
            if (doc != null &&
                doc['status'] == 'PENDING' &&
                (doc['version'] ?? 1) == 1)
              IconButton(
                tooltip: 'Remove unreviewed draft',
                icon: const Icon(Icons.delete_outline),
                onPressed: _assets!.busy
                    ? null
                    : () async {
                        if (await confirmOperation(
                          context,
                          'Remove draft document?',
                          'Only an original unreviewed draft can be removed. Reviewed or replaced evidence must be retained.',
                        )) {
                          await _assets!.removeDraftDocument(
                            doc['id'] as String,
                          );
                        }
                      },
              ),
          ],
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
      'vehicle_front_photo',
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
    if (session.roleEnrolment?['dashboardAccessible'] != true &&
        assets.loaded &&
        (!assets.approvedPartner ||
            assets.vehicles.isEmpty ||
            (assets.fleetMode &&
                !assets.vehicles.any(
                  (v) =>
                      providerStatus(
                        v['verificationStatus'] ?? v['approvalStatus'],
                      ) ==
                      ProviderStatus.approved,
                )))) {
      _guidedSetup = true;
    }
    if (_guidedSetup) return const GuidedProviderSetup();
    final rules = <String, DocumentRule>{
      for (final r in assets.rules.where((r) => !r.code.startsWith('vehicle_')))
        r.code: r,
    };
    for (final code in [
      'pan',
      'driving_licence',
      'profile_photo',
      'address_proof',
      'other',
    ]) {
      rules.putIfAbsent(code, () => DocumentRule(code));
    }
    for (final document in assets.documents.where(
      (d) => d['assignedVehicle'] == null,
    )) {
      final code =
          ((document['metadata'] as Map?)?['documentCode'] ??
                  document['documentType'].toString().toLowerCase())
              .toString();
      rules.putIfAbsent(code, () => DocumentRule(code));
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: !assets.fleetMode,
        title: assets.fleetMode && !widget.identityOnly && !widget.bankProofOnly
            ? InfurnusBrand(
                name: session.account?['firstName']?.toString() ?? 'Fleet',
              )
            : Text(
                widget.identityOnly
                    ? 'Identity & Verification'
                    : widget.bankProofOnly
                    ? 'Bank proof'
                    : 'Vehicles & documents',
              ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: assets.busy ? null : assets.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar:
          assets.fleetMode && !widget.identityOnly && !widget.bankProofOnly
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tab == 1)
                  SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: assets.busy ? null : _vehicle,
                          child: const Text('Add vehicle'),
                        ),
                      ),
                    ),
                  ),
                BottomNavigationBar(
                  currentIndex: _tab,
                  type: BottomNavigationBarType.fixed,
                  onTap: (value) => setState(() {
                    _tab = value;
                    _search = '';
                  }),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.directions_car_outlined),
                      label: 'Vehicles',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.people_outline),
                      label: 'Drivers',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.location_on_outlined),
                      label: 'Tracking',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.menu),
                      label: 'More',
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: ListView(
        key: ValueKey(_tab),
        padding: const EdgeInsets.all(16),
        children: [
          if (assets.busy) const LinearProgressIndicator(),
          if (assets.fleetMode && _tab == 0) ...[
            const ModeSelector(),
            const SizedBox(height: 8),
            FleetOverview(assets: assets),
          ],
          if (!assets.fleetMode || _tab == 1 || _tab == 2)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search vehicles and drivers',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
          if (assets.error != null)
            Text(assets.error!, style: const TextStyle(color: Colors.red)),
          if (!assets.fleetMode)
            TextButton(
              onPressed: () => context.go(session.landingPath),
              child: const Text('Back to Driver onboarding / dashboard'),
            ),
          if (assets.fleetMode &&
              _tab == 4 &&
              !widget.identityOnly &&
              !widget.bankProofOnly) ...[
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Identity & Verification'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ProviderAssetsScreen(identityOnly: true),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Bank Details & Payouts'),
              onTap: () => context.push('/provider/bank-account'),
            ),
          ],
          if (!assets.fleetMode || _tab == 4) ...[
            if (widget.identityOnly)
              const Text(
                'Verified means independent administrator documentary review, not government verification. Aadhaar collection requires the authorized masked-copy policy.',
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
              initiallyExpanded: widget.identityOnly || widget.bankProofOnly,
              title: Text(
                widget.bankProofOnly
                    ? 'Bank proof — choose one accepted document'
                    : 'Identity & Verification',
              ),
              children: widget.bankProofOnly
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Upload one cancelled cheque, passbook page or statement showing the account holder and bank details. This is documentary review, not automated bank verification.',
                        ),
                      ),
                      _document(const DocumentRule('bank_proof')),
                    ]
                  : [
                      for (final r in rules.values.where(
                        (r) => ![
                          'bank_proof',
                          'cancelled_cheque',
                          'bank_statement',
                          'bank_passbook',
                        ].contains(r.code),
                      ))
                        _document(r),
                    ],
            ),
          ],
          if (!assets.fleetMode || _tab == 1) ...[
            const Divider(),
            Text('Vehicles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final filter in ['All', 'Active', 'Inactive'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _vehicleFilter == filter,
                    onSelected: (_) => setState(() => _vehicleFilter = filter),
                  ),
              ],
            ),
            if (!assets.approvedPartner)
              const Text(
                'Add vehicles now. Approval is required before assignment and operations.',
              ),
            if (!assets.fleetMode)
              FilledButton(
                onPressed: assets.busy || assets.partner == null
                    ? null
                    : _vehicle,
                child: const Text('Add vehicle'),
              ),
            for (final v
                in assets.vehicles
                    .where(_matches)
                    .where(
                      (v) =>
                          _vehicleFilter == 'All' ||
                          (_vehicleFilter == 'Active'
                              ? v['isActive'] == true
                              : v['isActive'] == false),
                    ))
              Card(
                key: ValueKey('fleet-vehicle-${v['id']}'),
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Ops.surfaceOverlay,
                    child: Icon(
                      Icons.directions_car_outlined,
                      color: Ops.textPrimary,
                    ),
                  ),
                  title: Text('${v['make']} ${v['model']}'),
                  trailing: StatusPill(
                    (v['operationalStatus'] ??
                            v['approvalStatus'] ??
                            v['verificationStatus'] ??
                            'Unknown')
                        .toString(),
                  ),
                  subtitle: Text(
                    '${v['plateNumber']} • ${statusLabel(v['approvalStatus'] ?? v['verificationStatus'])}',
                  ),
                  children: [
                    Text('${v['sector']} · ${v['category']}'),
                    if (assets.fleetMode)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FleetVehicleRevenueScreen(
                              vehicleId: v['id'] as String,
                              name: v['plateNumber'].toString(),
                            ),
                          ),
                        ),
                        child: const Text('Vehicle revenue details'),
                      ),
                    if (v['activeAssignmentCode'] != null)
                      ListTile(
                        title: Text(
                          'Vehicle assignment code - ${v['assignmentCodeStatus'] ?? 'single use'}',
                        ),
                        subtitle: SelectableText(
                          v['activeAssignmentCode'].toString(),
                        ),
                      ),
                    if (v['assignedDriver'] is Map)
                      ListTile(
                        title: const Text('Assigned Driver'),
                        subtitle: Text(
                          v['assignedDriver']['name']?.toString() ?? 'Driver',
                        ),
                      ),
                    if (rejectionReason(v) != null) Text(rejectionReason(v)!),
                    TextButton(
                      onPressed: assets.busy ? null : () => _vehicle(v),
                      child: const Text('Edit vehicle'),
                    ),
                    TextButton(
                      onPressed: assets.busy
                          ? null
                          : () => _vehicleDocuments(v),
                      child: const Text('Vehicle documents'),
                    ),
                    _review(
                      'vehicle',
                      v['id'] as String,
                      'vehicle_verification',
                    ),
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
                                  : () => assets.operate(
                                      v['id'] as String,
                                      state,
                                    ),
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
                                  : () => assets.operate(
                                      v['id'] as String,
                                      state,
                                    ),
                              child: Text(state),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: assets.busy
                            ? null
                            : () async {
                                final eligible = assets.drivers
                                    .where(
                                      (d) =>
                                          d['verificationStatus'] ==
                                              'approved' &&
                                          d['assignedVehicle'] == null,
                                    )
                                    .toList();
                                final selected = await showDialog<String>(
                                  context: context,
                                  builder: (c) => SimpleDialog(
                                    title: const Text(
                                      'Select an eligible Driver',
                                    ),
                                    children: [
                                      SimpleDialogOption(
                                        onPressed: () => Navigator.pop(c, ''),
                                        child: const Text(
                                          'Any eligible Driver in my Fleet',
                                        ),
                                      ),
                                      if (eligible.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'No eligible unassigned Drivers. Add or review fleet memberships first.',
                                          ),
                                        ),
                                      for (final d in eligible)
                                        SimpleDialogOption(
                                          onPressed: () => Navigator.pop(
                                            c,
                                            d['id'] as String,
                                          ),
                                          child: Text(
                                            d['name']?.toString() ?? 'Driver',
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                                if (selected == null) return;
                                final code = await assets.assignmentCode(
                                  v['id'] as String,
                                  selected.isEmpty ? null : selected,
                                );
                                if (context.mounted && code != null) {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Fleet assignment code',
                                      ),
                                      content: SelectableText(
                                        '${code['code']}\nExpires: ${code['expiresAt']}',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
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
          ],
          if (assets.fleetMode && _tab == 2) ...[
            Text('Drivers', style: Theme.of(context).textTheme.titleLarge),
            if (!assets.approvedPartner)
              const Text(
                'Your business must be approved before creating or inviting Drivers. Complete the business details and request verification from the provider profile.',
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Create Driver profile'),
              onPressed: assets.busy
                  ? null
                  : () async {
                      if (!assets.approvedPartner) {
                        final review = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Business approval required'),
                            content: Text(
                              'Business status: ${statusLabel(assets.partner?['approvalStatus'])}. '
                              'Complete your business details and submit them for review. '
                              'Once approved, you can create Driver profiles here.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Close'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text(
                                  'Review business verification',
                                ),
                              ),
                            ],
                          ),
                        );
                        if (review == true && mounted) {
                          setState(() => _tab = 4);
                        }
                        return;
                      }
                      final input = await _form(
                        'Create Driver profile',
                        const {
                          'firstName': 'First name *',
                          'lastName': 'Last name *',
                          'email': 'Driver email *',
                          'phone': 'Phone with country code (optional)',
                          'licenseNumber': 'Driving licence number *',
                          'licenseExpiry': 'Licence expiry (YYYY-MM-DD) *',
                        },
                        requiredFields: {
                          'firstName',
                          'lastName',
                          'email',
                          'licenseNumber',
                          'licenseExpiry',
                        },
                      );
                      if (input == null) return;
                      Map<String, dynamic>? result;
                      final ok = await assets.run(() async {
                        result = Map<String, dynamic>.from(
                          await session.api.request(
                            'POST',
                            '/provider/managed-drivers',
                            body: input,
                          ) as Map,
                        );
                      });
                      if (ok && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ManagedDriverScreen(
                              userId: result!['userId'] as String,
                            ),
                          ),
                        );
                        await assets.refresh();
                      }
                    },
            ),
            const SizedBox(height: 12),
            if (assets.approvedPartner)
              ApiPanel(
                embedded: true,
                api: session.api,
                path: '/provider/managed-drivers',
                builder: (context, data) => Column(
                  children: [
                    for (final row in data as List)
                      ListTile(
                        title: Text('${row['firstName']} ${row['lastName']}'),
                        subtitle: Text(
                          'Onboarding: ${row['verificationStatus']}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ManagedDriverScreen(
                              userId: row['userId'] as String,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: assets.busy || !assets.approvedPartner
                  ? null
                  : () async {
                      final input = await _form(
                        'Add Driver',
                        {'email': 'Registered Driver email'},
                        requiredFields: {'email'},
                      );
                      if (input == null) return;
                      Map<String, dynamic>? invite;
                      final ok = await assets.run(() async {
                        invite = Map<String, dynamic>.from(
                          await session.api.request(
                            'POST',
                            '/provider/fleet-drivers',
                            body: input,
                          ) as Map,
                        );
                      });
                      if (ok && context.mounted) {
                        await showDialog<void>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Fleet invitation'),
                            content: SelectableText(
                              'Invitation created. The Driver can accept from Account > Fleet invitations. Expires: ${invite!['expiresAt']}',
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
                    },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite an existing Driver'),
            ),
            for (final invite in assets.invitations)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${invite['firstName']} ${invite['lastName']}'),
                subtitle: Text(
                  'Onboarding invitation: ${invite['status']} - Expires ${invite['expiresAt']}',
                ),
              ),
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Fleet driver memberships'),
              children: [
                if (assets.drivers.isEmpty)
                  const ListTile(title: Text('No driver memberships')),
                for (final d in assets.drivers.where(_matches))
                  Card(
                    child: ListTile(
                      onTap: () => context.push(
                        '/fleet/drivers/${Uri.encodeComponent((d['driverProfileId'] ?? d['id']) as String)}',
                      ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Ops.surfaceOverlay,
                        child: Text(
                          (d['name']?.toString() ?? 'D').trim().isEmpty
                              ? 'D'
                              : d['name'].toString().trim()[0].toUpperCase(),
                          style: const TextStyle(color: Ops.success),
                        ),
                      ),
                      title: Text(
                        d['name']?.toString() ?? 'Driver',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        d['availabilityStatus']?.toString().replaceAll(
                              '_',
                              ' ',
                            ) ??
                            'Availability unavailable',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusPill(
                            (d['status'] ?? d['membershipStatus'] ?? 'Unknown')
                                .toString(),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Driver actions',
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'deactivate',
                                child: Text(
                                  'Deactivate membership',
                                  style: TextStyle(color: Ops.error),
                                ),
                              ),
                            ],
                            onSelected: assets.busy
                                ? null
                                : (value) async {
                                    if (value == 'deactivate' &&
                                        await confirmOperation(
                                          context,
                                          'Deactivate driver membership?',
                                          'The driver will lose this fleet association.',
                                        )) {
                                      await assets.deactivateMembership(
                                        (d['driverProfileId'] ?? d['id'])
                                            as String,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (assets.fleetMode && _tab == 3) ...[
            FleetLocationMap(rows: assets.tracking),
            ExpansionTile(
              title: const Text('Location records'),
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
          if ((!assets.fleetMode || _tab == 4) &&
              !widget.identityOnly &&
              !widget.bankProofOnly) ...[
            if (assets.fleetMode) ...[
              const ModeSelector(),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Revenue & reports'),
                onTap: () => context.push('/fleet/reports'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile & settings'),
                onTap: () => context.push('/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Support'),
                onTap: () => context.push('/support-tickets'),
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
              title: const Text('Settlement ledger'),
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
        ],
      ),
    );
  }
}

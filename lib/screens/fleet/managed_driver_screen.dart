import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../models/onboarding_rules.dart';
import '../../widgets/operations.dart';
import '../auth/document_upload_dialog.dart';

class ManagedDriverScreen extends StatefulWidget {
  final String userId;
  const ManagedDriverScreen({super.key, required this.userId});
  @override
  State<ManagedDriverScreen> createState() => _ManagedDriverScreenState();
}

class _ManagedDriverScreenState extends State<ManagedDriverScreen> {
  int _version = 0;
  String? _error;
  bool _busy = false;
  Future<void> _upload(DocumentRule rule) async {
    final session = context.read<DriverSession>();
    const types = {
      'driver_license': 'driver_license',
      'driving_licence': 'driver_license',
      'profile_photo': 'profile_photo',
      'aadhaar': 'identity',
      'identity': 'identity',
      'pan': 'pan',
      'vehicle_rc': 'vehicle_rc',
    };
    final type = types[rule.code] ?? 'other';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DocumentUploadDialog(
        session: session,
        rule: rule,
        errorMessage: () => _error,
        uploader: (r, files, metadata) async {
          try {
            await session.api.request(
              'POST',
              '/provider/managed-drivers/${widget.userId}/documents/$type${type == 'profile_photo' ? '' : '/pages'}',
              files: files,
              fileField: type == 'profile_photo' ? 'file' : 'files',
              fields: {
                ...metadata,
                if (type == 'other') 'documentCode': r.code,
              },
            );
            return true;
          } catch (e) {
            _error = e.toString();
            return false;
          }
        },
      ),
    );
    if (mounted) setState(() => _version++);
  }

  Future<void> _edit(Map profile) async {
    final form = GlobalKey<FormState>();
    final licence = TextEditingController(
      text: profile['licenseNumber']?.toString() ?? '',
    );
    final expiry = TextEditingController(
      text: profile['licenseExpiry']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Driver licence'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: licence,
                decoration: const InputDecoration(labelText: 'Licence number'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: expiry,
                decoration: const InputDecoration(
                  labelText: 'Expiry (YYYY-MM-DD)',
                ),
                validator: (v) =>
                    v == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)
                    ? 'Enter YYYY-MM-DD'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await context.read<DriverSession>().api.request(
          'PATCH',
          '/provider/managed-drivers/${widget.userId}/profile',
          body: {
            'licenseNumber': licence.text.trim(),
            'licenseExpiry': expiry.text.trim(),
          },
        );
        if (mounted) setState(() => _version++);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    // The dialog can animate out after its result completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    licence.dispose();
    expiry.dispose();
  }

  Future<void> _assign() async {
    final code = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Assign Fleet vehicle'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the six-digit code shown on your vehicle. Driver approval and Fleet association are required.',
              ),
              TextFormField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Vehicle code'),
                validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v)
                    ? null
                    : 'Enter all six digits',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Assign vehicle'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await context.read<DriverSession>().api.request(
          'POST',
          '/provider/managed-drivers/${widget.userId}/assignment',
          body: {'code': code.text},
        );
        if (mounted) setState(() => _version++);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    code.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<DriverSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Driver onboarding')),
      body: ApiPanel(
        key: ValueKey(_version),
        api: session.api,
        path: '/provider/managed-drivers/${widget.userId}',
        builder: (context, value) {
          final data = value as Map, profile = data['profile'] as Map;
          final rules = <String, DocumentRule>{
            for (final row in data['requirements'] as List)
              DocumentRule.fromJson(Map<String, dynamic>.from(row as Map))
                  .code: DocumentRule.fromJson(
                Map<String, dynamic>.from(row),
              ),
          };
          if (!rules.containsKey('driving_licence')) {
            rules.putIfAbsent(
              'driver_license',
              () => const DocumentRule(
                'driver_license',
                required: true,
                requiresExpiry: true,
              ),
            );
          }
          rules.putIfAbsent(
            'profile_photo',
            () => const DocumentRule('profile_photo'),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${profile['firstName']} ${profile['lastName']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Verification: ${profile['verificationStatus']}'),
              Text(
                profile['assignedVehicle'] == null
                    ? 'Vehicle: Unassigned'
                    : 'Vehicle: ${profile['assignedVehicle']['plateNumber']}',
              ),
              OutlinedButton(
                onPressed: _busy ? null : _assign,
                child: const Text('Assign vehicle using code'),
              ),
              Text(
                'Licence: ${profile['licenseNumber']} · ${profile['licenseExpiry']}',
              ),
              TextButton(
                onPressed: _busy ? null : () => _edit(profile),
                child: const Text('Edit licence details'),
              ),
              const Text(
                'The Driver signs in with their own OTP. Saved information is not approval to drive.',
              ),
              const SizedBox(height: 16),
              for (final rule in rules.values)
                ListTile(
                  title: Text(rule.label),
                  subtitle: Text(
                    (data['documents'] as List)
                        .where(
                          (d) =>
                              d['documentType'] ==
                              (rule.code == 'driving_licence'
                                  ? 'driver_license'
                                  : rule.code),
                        )
                        .map((d) => d['verificationStatus'])
                        .join(', '),
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _upload(rule),
                    child: const Text('Upload'),
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          await session.api.request(
                            'POST',
                            '/provider/managed-drivers/${widget.userId}/submit',
                            body: {},
                          );
                          if (context.mounted) {
                            setState(() => _version++);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Submitted for review. Approval is still required.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) setState(() => _error = e.toString());
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(
                  profile['verificationStatus'] == 'approved'
                      ? 'Request Fleet association'
                      : 'Submit Driver onboarding',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

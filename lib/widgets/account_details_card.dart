import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';

class AccountDetailsCard extends StatefulWidget {
  const AccountDetailsCard({super.key});
  @override
  State<AccountDetailsCard> createState() => _AccountDetailsCardState();
}

class _AccountDetailsCardState extends State<AccountDetailsCard> {
  bool _expanded = true, _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<DriverSession>();
      final account = await session.api.request('GET', '/provider/account');
      if (mounted) {
        session.providerAccount = Map<String, dynamic>.from(account as Map);
      }
    } catch (_) {
      if (mounted) _error = 'Account details could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final session = context.read<DriverSession>();
    final account = session.providerAccount ?? session.account ?? {};
    final fields = {
      'firstName': 'First Name',
      'lastName': 'Last Name',
      'phone': 'Mobile Number',
      'email': 'Email Address',
    };
    final controllers = {
      for (final key in fields.keys)
        key: TextEditingController(text: account[key]?.toString() ?? ''),
    };
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Personal Information'),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final field in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: controllers[field.key],
                          enabled: !saving,
                          decoration: InputDecoration(labelText: field.value),
                          keyboardType: field.key == 'email'
                              ? TextInputType.emailAddress
                              : field.key == 'phone'
                              ? TextInputType.phone
                              : TextInputType.name,
                          maxLength: field.key == 'email'
                              ? 254
                              : field.key == 'phone'
                              ? 16
                              : 100,
                          validator: (raw) {
                            final value = raw?.trim() ?? '';
                            if (value.isEmpty) {
                              return account[field.key] == null &&
                                      ['email', 'phone'].contains(field.key)
                                  ? null
                                  : 'Enter ${field.value.toLowerCase()}';
                            }
                            if (field.key == 'email' &&
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            if (field.key == 'phone' &&
                                !RegExp(r'^\+?[1-9]\d{7,14}$')
                                    .hasMatch(value)) {
                              return 'Enter a valid mobile number';
                            }
                            return null;
                          },
                        ),
                      ),
                    const Text(
                      'Contact changes do not change your verified sign-in identity.',
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        final input = <String, dynamic>{
                          for (final key in fields.keys)
                            if (controllers[key]!.text.trim().isNotEmpty &&
                                controllers[key]!.text.trim() != account[key])
                              key: controllers[key]!.text.trim(),
                        };
                        final ok =
                            input.isEmpty || await session.saveAccount(input);
                        if (!dialogContext.mounted || !mounted) return;
                        if (ok) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Profile saved')),
                          );
                        } else {
                          update(() {
                            saving = false;
                            error =
                                session.error ??
                                'Unable to save. Your changes are retained.';
                          });
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
    // Wait for the dialog transition before disposing its text controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<DriverSession>().providerAccount ?? {};
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Account Details'),
            trailing: IconButton(
              tooltip: _expanded
                  ? 'Collapse account details'
                  : 'Expand account details',
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded) ...[
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            for (final field in {
              'firstName': 'First Name',
              'lastName': 'Last Name',
              'phone': 'Mobile Number',
              'email': 'Email Address',
            }.entries)
              ListTile(
                title: Text(field.value),
                subtitle: Text(
                  account[field.key]?.toString().isNotEmpty == true
                      ? account[field.key].toString()
                      : _error != null
                      ? 'Unavailable'
                      : 'Not provided',
                ),
              ),
            TextButton.icon(
              onPressed: _loading || _error != null ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Personal Information'),
            ),
          ],
        ],
      ),
    );
  }
}

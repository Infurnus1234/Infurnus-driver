import '../fleet/provider_assets_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';
import '../../core/operations_theme.dart';
import '../../services/api_service.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});
  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'accountHolderName',
      'accountNumber',
      'accountNumberConfirmation',
      'ifscCode',
      'bankName',
      'branchName',
      'legalEntityName',
      'upiId',
    ])
      key: TextEditingController(),
  };
  String _accountType = 'SAVINGS', _ownershipType = 'INDIVIDUAL';
  String? _proofId;
  Map? _bank;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bank = await context.read<DriverSession>().api.request(
        'GET',
        '/provider/bank-account',
      );
      if (mounted) {
        setState(() {
          _bank = bank as Map?;
          _proofId = _bank?['supportingDocumentId'] as String?;
          _accountType = _bank?['accountType'] as String? ?? 'SAVINGS';
          _ownershipType = _bank?['ownershipType'] as String? ?? 'INDIVIDUAL';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to load bank account.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!await confirmOperation(
      context,
      'Save bank details?',
      'Saving replaces the account details and requires verification again. Payouts require a verified account.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bank = await context.read<DriverSession>().api.request(
        'POST',
        '/provider/bank-account',
        body: {
          'accountType': _accountType,
          'ownershipType': _ownershipType,
          if (_proofId != null) 'supportingDocumentId': _proofId,
          for (final field in _fields.entries)
            if (field.key != 'accountNumberConfirmation' &&
                (![
                      'upiId',
                      'branchName',
                      'legalEntityName',
                    ].contains(field.key) ||
                    field.value.text.trim().isNotEmpty))
              field.key: field.key == 'ifscCode'
                  ? field.value.text.trim().toUpperCase()
                  : field.value.text.trim(),
        },
      );
      if (mounted) {
        setState(() => _bank = bank as Map);
        for (final field in _fields.values) {
          field.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bank details saved. Verification status comes from the server.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Bank details could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseProof() async {
    try {
      final api = context.read<DriverSession>().api;
      final partner = await api.request('GET', '/partners/me') as Map;
      final documents = await api.request(
        'GET',
        '/partners/${partner['id']}/documents',
      ) as List;
      final proofs = documents
          .where(
            (d) =>
                d['vehicleId'] == null &&
                [
                  'bank_proof',
                  'cancelled_cheque',
                  'bank_passbook',
                  'bank_statement',
                ].contains((d['metadata'] as Map?)?['documentCode']),
          )
          .toList();
      if (!mounted) return;
      if (proofs.isEmpty) {
        setState(
          () => _error = 'Upload a cancelled cheque, passbook page or bank statement first. One accepted proof is sufficient.',
        );
        return;
      }
      final selected = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Choose bank proof'),
          children: [
            for (final d in proofs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, d['id'] as String),
                child: Text('Bank proof — ${d['status']}'),
              ),
          ],
        ),
      );
      if (selected != null && mounted) setState(() => _proofId = selected);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException ? e.message : 'Unable to load bank proof. Create your business profile first.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bank Details & Payouts')),
    body: ListView(
      padding: const EdgeInsets.all(Ops.padding),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) OpsError(_error!, retry: _load),
        if (_bank != null)
          OpsPanel(
            title: _bank!['bankName']?.toString() ?? 'Saved bank account',
            child: Text(
              'Account ending ${_bank!['accountNumberLast4'] ?? 'unavailable'}\n${_bank!['isVerified'] == true
                  ? 'Verified'
                  : _bank!['reviewStatus'] == 'REJECTED'
                  ? 'Changes required'
                  : 'Verification pending'}${_bank!['rejectionReason'] == null ? '' : '\n${_bank!['rejectionReason']}'}',
            ),
          ),
        if (_bank == null && !_busy && _error == null)
          const OpsEmpty('No bank account saved.'),
        const Text(
          'Format checks do not verify ownership. Documentary review is manual; payouts remain disabled until bank ownership is verified through an authorized process.',
        ),
        DropdownButtonFormField<String>(
          initialValue: _accountType,
          decoration: const InputDecoration(labelText: 'Account type'),
          items: const [
            DropdownMenuItem(value: 'SAVINGS', child: Text('Savings')),
            DropdownMenuItem(value: 'CURRENT', child: Text('Current')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
          ],
          onChanged: _busy ? null : (v) => setState(() => _accountType = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: _ownershipType,
          decoration: const InputDecoration(labelText: 'Account ownership'),
          items: const [
            DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
            DropdownMenuItem(
              value: 'BUSINESS',
              child: Text('Registered business'),
            ),
          ],
          onChanged: _busy ? null : (v) => setState(() => _ownershipType = v!),
        ),
        TextButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload or replace one bank proof'),
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ProviderAssetsScreen(bankProofOnly: true),
                  ),
                ),
        ),
        TextButton(
          onPressed: _busy ? null : _chooseProof,
          child: Text(
            _proofId == null
                ? 'Link uploaded bank proof'
                : 'Change linked bank proof',
          ),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in _fields.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    key: ValueKey('bank-${field.key}'),
                    controller: field.value,
                    enabled: !_busy,
                    obscureText: field.key.startsWith('accountNumber'),
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: field.key.startsWith('accountNumber')
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: const {
                        'accountHolderName': 'Account holder name',
                        'accountNumber': 'Account number',
                        'accountNumberConfirmation': 'Confirm account number',
                        'ifscCode': 'IFSC code',
                        'bankName': 'Bank name',
                        'branchName': 'Branch name (optional)',
                        'legalEntityName':
                            'Registered entity name (business only)',
                        'upiId': 'UPI ID (optional)',
                      }[field.key],
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (field.key == 'branchName') {
                        return text.length > 150
                            ? 'Maximum 150 characters'
                            : null;
                      }
                      if (field.key == 'legalEntityName') {
                        return _ownershipType == 'BUSINESS' && text.length < 2
                            ? 'Enter the registered business name'
                            : null;
                      }
                      if (field.key == 'upiId') {
                        return text.length > 100
                            ? 'Maximum 100 characters'
                            : null;
                      }
                      if (field.key == 'accountNumber') {
                        return RegExp(r'^\d{8,30}$').hasMatch(text)
                            ? null
                            : 'Enter 8–30 digits';
                      }
                      if (field.key == 'accountNumberConfirmation') {
                        return text == _fields['accountNumber']!.text.trim() &&
                                text.isNotEmpty
                            ? null
                            : 'Account numbers must match';
                      }
                      if (field.key == 'ifscCode') {
                        return RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                                .hasMatch(text.toUpperCase())
                            ? null
                            : 'Enter a valid 11-character IFSC code';
                      }
                      final max = field.key == 'accountHolderName'
                          ? 150
                          : field.key == 'bankName'
                          ? 100
                          : 20;
                      final min = field.key == 'ifscCode' ? 4 : 2;
                      return text.length < min || text.length > max
                          ? 'Enter $min–$max characters'
                          : null;
                    },
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save for verification'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

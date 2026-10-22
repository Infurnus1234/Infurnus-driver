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
      'ifscCode',
      'bankName',
      'upiId',
    ])
      key: TextEditingController(),
  };
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
      if (mounted) setState(() => _bank = bank as Map?);
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
          for (final field in _fields.entries)
            if (field.key != 'upiId' || field.value.text.trim().isNotEmpty)
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bank account')),
    body: ListView(
      padding: const EdgeInsets.all(Ops.padding),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) OpsError(_error!, retry: _load),
        if (_bank != null)
          OpsPanel(
            title: _bank!['bankName']?.toString() ?? 'Saved bank account',
            child: Text(
              'Account ending ${_bank!['accountNumberLast4'] ?? 'unavailable'}\n${_bank!['isVerified'] == true ? 'Verified' : 'Verification pending'}',
            ),
          ),
        if (_bank == null && !_busy && _error == null)
          const OpsEmpty('No bank account saved.'),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in _fields.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    controller: field.value,
                    enabled: !_busy,
                    obscureText: field.key == 'accountNumber',
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: field.key == 'accountNumber'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: const {
                        'accountHolderName': 'Account holder name',
                        'accountNumber': 'Account number',
                        'ifscCode': 'IFSC code',
                        'bankName': 'Bank name',
                        'upiId': 'UPI ID (optional)',
                      }[field.key],
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
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

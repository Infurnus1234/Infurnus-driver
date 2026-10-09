import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../widgets/google_sign_in_button.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _fields = {
    for (final key in [
      'firstName',
      'lastName',
      'email',
      'phone',
      'password',
      'confirmPassword',
      'licenseNumber',
      'licenseExpiry',
      'businessName',
    ])
      key: TextEditingController(),
  };
  String _role = 'driver';
  bool _details = false;
  bool _passwordMethod = false;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final labels = _details
        ? {
            if (_role != 'fleet_owner')
              'licenseNumber': 'Driving licence number *',
            if (_role != 'fleet_owner')
              'licenseExpiry': 'Licence expiry (YYYY-MM-DD) *',
            if (_role != 'driver') 'businessName': 'Business name *',
          }
        : const {
            'firstName': 'First name *',
            'lastName': 'Last name *',
            'email': 'Email (or phone required)',
            'phone': 'Phone (or email required)',
            'password': 'Password *',
            'confirmPassword': 'Confirm password *',
          };
    return Scaffold(
      appBar: AppBar(
        title: Text(_details ? 'Registration details' : 'Create your account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_details) {
              setState(() => _details = false);
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_details) ...[
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Account role'),
              items: const [
                DropdownMenuItem(value: 'driver', child: Text('Driver')),
                DropdownMenuItem(
                  value: 'fleet_owner',
                  child: Text('Fleet Owner'),
                ),
                DropdownMenuItem(
                  value: 'driver_fleet_owner',
                  child: Text('Driver + Fleet Owner'),
                ),
              ],
              onChanged: session.busy
                  ? null
                  : (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 16),
            GoogleSignInButton(
              signUp: true,
              enabled: !session.busy,
              onIdToken: (token) async {
                await session.authenticateGoogle(
                  token,
                  signup: true,
                  providerRole: _role,
                );
                if (context.mounted && session.authenticated) {
                  context.go(session.landingPath);
                }
              },
            ),
            const Text(
              'Google signup authenticates your selected provider role. Complete its onboarding next. Google identity does not approve your licence, KYC or vehicle.',
            ),
            const Text(
              'Google takes you directly to onboarding without an OTP code.',
            ),
            const Divider(),
            TextButton(
              onPressed: session.busy
                  ? null
                  : () => setState(() => _passwordMethod = !_passwordMethod),
              child: Text(
                _passwordMethod
                    ? 'Hide email/phone signup'
                    : 'Use email/phone signup (OTP)',
              ),
            ),
          ] else
            const Text(
              'These registration details are required by the backend before account OTP verification. Upload documents after authentication. Approval is reviewed separately.',
            ),
          for (final entry
              in (_details || _passwordMethod ? labels : <String, String>{})
                  .entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _fields[entry.key],
                enabled: !session.busy,
                obscureText: entry.key.contains('assword'),
                maxLength: entry.key == 'businessName'
                    ? 150
                    : entry.key == 'licenseNumber'
                    ? 50
                    : entry.key.contains('assword')
                    ? 128
                    : entry.key == 'email'
                    ? 320
                    : entry.key.contains('Name')
                    ? 100
                    : null,
                keyboardType: entry.key == 'phone'
                    ? TextInputType.phone
                    : entry.key == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                decoration: InputDecoration(labelText: entry.value),
              ),
            ),
          if (session.error != null)
            Text(session.error!, style: const TextStyle(color: Colors.red)),
          if (_details || _passwordMethod)
            FilledButton(
              onPressed: session.busy
                  ? null
                  : () async {
                      if (!_details) {
                        setState(() => _details = true);
                        return;
                      }
                      final input = <String, dynamic>{
                        'role': _role,
                        for (final e in _fields.entries)
                          if (e.value.text.trim().isNotEmpty &&
                              !(_role == 'fleet_owner' &&
                                  e.key.startsWith('license')) &&
                              !(_role == 'driver' && e.key == 'businessName'))
                            e.key: e.key.contains('assword')
                                ? e.value.text
                                : e.key == 'phone'
                                ? e.value.text.replaceAll(
                                    RegExp(r'[\s()-]'),
                                    '',
                                  )
                                : e.value.text.trim(),
                      };
                      final ok = await session.signup(input);
                      if (ok) {
                        _fields['password']!.clear();
                        _fields['confirmPassword']!.clear();
                      }
                      if (context.mounted && ok) context.go('/otp');
                    },
              child: Text(
                session.busy
                    ? 'Starting signup…'
                    : _details
                    ? 'Send account verification code'
                    : 'Continue',
              ),
            ),
          TextButton(
            onPressed: session.busy ? null : () => context.go('/login'),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }
}

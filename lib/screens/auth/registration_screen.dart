import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/signup_verification_layout.dart';
import '../../models/signup_phone.dart';
import 'role_selection_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String? initialRole;

  /// When 'email_phone', hides the Google signup option and opens the
  /// email/phone form directly. Null or any other value shows Google so the
  /// user can switch to it (e.g. when entering /register directly).
  final String? signupVia;

  const RegistrationScreen({super.key, this.initialRole, this.signupVia});

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

  @override
  void initState() {
    super.initState();
    if ([
      'driver',
      'fleet_owner',
      'driver_fleet_owner',
    ].contains(widget.initialRole)) {
      _role = widget.initialRole!;
    }
    // When arriving via email/phone signup, open the form directly without
    // requiring the user to tap the toggle button.
    if (widget.signupVia == 'email_phone') {
      _passwordMethod = true;
    }
  }

  final _countryCode = TextEditingController(text: '+91');
  String? _validationError;
  bool _details = false;
  bool _passwordMethod = false;

  /// True when the Google option should be rendered. Hidden when the user
  /// explicitly chose "Sign up with email or phone" from the login screen.
  bool get _showGoogle => widget.signupVia != 'email_phone';

  @override
  void dispose() {
    _countryCode.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final labels = _details
        ? {if (_role != 'driver') 'businessName': 'Business name *'}
        : {
            'firstName': 'First name *',
            'lastName': 'Last name *',
            'email': 'Email (or phone required)',
            'phone': 'Phone (or email required)',
            if (_role != 'driver') 'password': 'Password *',
            if (_role != 'driver') 'confirmPassword': 'Confirm password *',
          };
    return SignupVerificationLayout(
      title: _details ? 'Registration details' : 'Create your account',
      onBack: session.busy
          ? null
          : () {
              if (_details) {
                setState(() => _details = false);
              } else {
                context.go('/login');
              }
            },
      children: [
        if (!_details) ...[
          ProviderRoleCards(
            selected: _role,
            onChanged: session.busy
                ? null
                : (value) => setState(() => _role = value),
          ),
          const SizedBox(height: 16),
          if (_showGoogle) ...[
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
          ],
        ] else
          const Text(
            'Confirm your business details. Your licence photo, number and expiry are collected together after sign-in. Approval is reviewed separately.',
          ),
        if (_passwordMethod && !_details) ...[
          TextField(
            controller: _countryCode,
            enabled: !session.busy,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone country code',
              helperText: 'India +91. For another country, change this code or enter a full + number.',
            ),
          ),
        ],
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
        if (_validationError != null)
          Text(
            _validationError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (session.error != null)
          Text(session.error!, style: const TextStyle(color: Colors.red)),
        if (_details || _passwordMethod)
          FilledButton(
            onPressed: session.busy
                ? null
                : () async {
                    if (!_details && _role != 'driver') {
                      setState(() => _details = true);
                      return;
                    }
                    setState(() => _validationError = null);
                    String phone;
                    try {
                      phone = normalizeSignupPhone(
                        _fields['phone']!.text,
                        countryCode: _countryCode.text.trim(),
                      );
                    } on FormatException catch (e) {
                      setState(() => _validationError = e.message);
                      return;
                    }
                    final input = <String, dynamic>{
                      'role': _role,
                      if (_role != 'fleet_owner')
                        'onboardingLicencePending': true,
                      for (final e in _fields.entries)
                        if (e.value.text.trim().isNotEmpty &&
                            !(_role == 'fleet_owner' &&
                                e.key.startsWith('license')) &&
                            !(_role == 'driver' && e.key == 'businessName'))
                          e.key: e.key.contains('assword')
                              ? e.value.text
                              : e.key == 'phone'
                              ? phone
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
                  : (_details || _role == 'driver')
                  ? 'Send account verification code'
                  : 'Continue',
            ),
          ),
        TextButton(
          onPressed: session.busy ? null : () => context.go('/login'),
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}

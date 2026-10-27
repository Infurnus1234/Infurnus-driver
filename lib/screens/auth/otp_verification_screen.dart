import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../widgets/signup_verification_layout.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = TextEditingController();
  Timer? _timer;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify(DriverSession session) async {
    if (_submitting ||
        session.busy ||
        !RegExp(r'^\d{6}$').hasMatch(_otp.text)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final signup = session.signupId != null;
      final ok = await session.verify(_otp.text);
      if (mounted && ok && session.authenticated) {
        _otp.clear();
        context.go(signup ? '/onboarding' : session.landingPath);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final signup = session.signupId != null;
    final active = signup || session.challengeId != null;
    final busy = session.busy || _submitting;
    final remaining =
        (session.verificationResendAt?.difference(DateTime.now()).inSeconds ??
                0)
            .clamp(0, 86400);
    final expires = signup ? session.api.signupOtpExpiresAt : null;
    final expired = expires != null && !expires.isAfter(DateTime.now());
    return SignupVerificationLayout(
      title: 'Verify your account',
      onBack: busy ? null : () => context.go(signup ? '/register' : '/login'),
      children: [
        Text(
          'Enter your verification code',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          active
              ? 'Enter the 6-digit code for ${session.verificationContact ?? 'your registered contact'}.'
              : 'Start signup or login to request a verification code.',
        ),
        if (!signup) ...[
          const SizedBox(height: 12),
          const Text(
            'Login codes are sent only to registered accounts. If you have not signed up in this environment, create an account first.',
          ),
          TextButton(
            onPressed: busy ? null : () => context.go('/role-selection'),
            child: const Text('Create an account'),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _otp,
          enabled: active && !busy && !expired,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Verification code',
            helperText: 'Enter all six digits',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _verify(session),
        ),
        if (expired)
          const Text(
            'This code has expired. Start signup again to request a new code.',
          ),
        if (session.error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              session.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              active &&
                  !busy &&
                  !expired &&
                  RegExp(r'^\d{6}$').hasMatch(_otp.text)
              ? () => _verify(session)
              : null,
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify & Continue'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: !active || busy || expired || remaining > 0
              ? null
              : () async {
                  if (_submitting) return;
                  setState(() => _submitting = true);
                  try {
                    final ok = await session.resend();
                    if (ok && context.mounted) {
                      _otp.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification code request accepted.'),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          child: Text(
            remaining > 0
                ? 'Resend in ${remaining}s'
                : 'Resend verification code',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => context.go(signup ? '/register' : '/login'),
          child: Text(
            signup ? 'Change signup details' : 'Change login details',
          ),
        ),
      ],
    );
  }
}

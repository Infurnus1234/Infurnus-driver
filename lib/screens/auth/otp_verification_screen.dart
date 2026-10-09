import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = TextEditingController();
  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: session.busy ? null : () => context.go('/login'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Enter Verification Code', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          const Text(
            'Enter the six-digit code sent to your registered contact.',
          ),
          TextField(
            controller: _otp,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'Verification code'),
          ),
          if (session.error != null)
            Text(session.error!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: session.busy
                ? null
                : () async {
                    final signup = session.signupId != null;
                    await session.verify(_otp.text);
                    _otp.clear();
                    if (context.mounted && session.authenticated) {
                      context.go(signup ? '/onboarding' : session.landingPath);
                    }
                  },
            child: Text(session.busy ? 'Verifying…' : 'Verify & Continue'),
          ),
          TextButton(
            onPressed: session.busy
                ? null
                : () async {
                    await session.resend();
                  },
            child: const Text('Resend OTP'),
          ),
        ],
      ),
    );
  }
}

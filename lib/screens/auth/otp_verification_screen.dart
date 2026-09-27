import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController(text: '9'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.mark_email_read_outlined, size: 60, color: InfurnusTheme.accentOrange),
              const SizedBox(height: 16),
              const Text(
                'Enter Verification Code',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 4-digit verification code to your registered mobile number.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 55,
                    child: TextField(
                      controller: _controllers[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        fillColor: InfurnusTheme.primaryDark,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  final appState = Provider.of<AppState>(context, listen: false);
                  if (appState.currentUser == null) {
                    context.go('/role-selection');
                  } else {
                    context.go('/driver/dashboard');
                  }
                },
                child: const Text('Verify & Continue'),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resent OTP to registered phone number.')),
                  );
                },
                child: const Text('Resend OTP', style: TextStyle(color: InfurnusTheme.accentOrange)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

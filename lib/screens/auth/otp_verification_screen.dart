import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
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
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'OTP Verification'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, size: 50, color: InfurnusTheme.primaryGreen),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter Verification Code',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'We sent a 4-digit verification code to your registered mobile number.',
                textAlign: TextAlign.center,
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
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
                      style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: '',
                        fillColor: Colors.white,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
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
                child: const Text('Resend OTP', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

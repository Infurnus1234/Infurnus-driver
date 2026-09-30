import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91 98765 00112');
  final _passwordController = TextEditingController(text: '123456');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: InfurnusTheme.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 48,
                        color: InfurnusTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'INFURNUS',
                      style: TextStyle(
                        color: InfurnusTheme.textDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Provider & Logistics Platform',
                      style: TextStyle(
                        color: InfurnusTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              const Text(
                'Welcome Back',
                style: TextStyle(
                  color: InfurnusTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Login to access Driver or Fleet Owner Portal',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _phoneController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Mobile Number or Email',
                  prefixIcon: Icon(Icons.phone_android, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Password / OTP',
                  prefixIcon: Icon(Icons.lock_outline, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final appState = Provider.of<AppState>(context, listen: false);
                  appState.login(_phoneController.text);
                  context.go('/driver/dashboard');
                },
                child: const Text('Log In with Password'),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: InfurnusTheme.buttonBlack,
                  side: const BorderSide(color: InfurnusTheme.buttonBlack, width: 1.5),
                ),
                onPressed: () {
                  context.push('/otp');
                },
                child: const Text('Send OTP Code'),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have a provider account? ",
                    style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/register');
                    },
                    child: const Text(
                      'Register Now',
                      style: TextStyle(
                        color: InfurnusTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

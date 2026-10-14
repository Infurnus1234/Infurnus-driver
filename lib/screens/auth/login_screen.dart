import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/driver_session.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/infurnus_logo.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _useEmail = false;
  String? _clientValidationMessage;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  void _validateAndSubmit(DriverSession session) async {
    setState(() => _clientValidationMessage = null);
    final rawInput = _identifier.text.trim();
    final pass = _password.text;

    if (rawInput.isEmpty) {
      setState(() {
        _clientValidationMessage = _useEmail
            ? 'Please enter your email address.'
            : 'Please enter your 10-digit mobile number.';
      });
      return;
    }

    if (_useEmail || rawInput.contains('@')) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(rawInput)) {
        setState(() => _clientValidationMessage = 'Please enter a valid email address.');
        return;
      }
    } else {
      final digits = rawInput.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) {
        setState(() => _clientValidationMessage = 'Please enter a valid 10-digit mobile number.');
        return;
      }
    }

    if (pass.isEmpty) {
      setState(() => _clientValidationMessage = 'Please enter your password.');
      return;
    }

    final fullIdentifier = !_useEmail && !rawInput.contains('@') && !rawInput.startsWith('+')
        ? '+91$rawInput'
        : rawInput;

    final success = await session.login(fullIdentifier, pass);
    if (!mounted) return;
    _password.clear();
    if (success) {
      context.go('/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: InfurnusTheme.textDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
        centerTitle: true,
        title: const InfurnusLogo(iconSize: 26, fontSize: 18),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            const SizedBox(height: 12),
            // Reference Phone Illustration Hero
            Center(
              child: Container(
                width: 80,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                    Positioned(
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: InfurnusTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: InfurnusTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Subtitle matching Reference UI
            Text(
              'Welcome Back',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: InfurnusTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _useEmail ? 'Enter your email' : 'Enter your mobile number',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: InfurnusTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll send you an OTP to verify your account",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: InfurnusTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),

            // Phone or Email Field
            if (!_useEmail)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            '+91',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: InfurnusTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18, color: InfurnusTheme.textMuted),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _identifier,
                        enabled: !session.busy,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: '98765 43210',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextField(
                controller: _identifier,
                enabled: !session.busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

            const SizedBox(height: 14),

            // Password Input
            TextField(
              controller: _password,
              enabled: !session.busy,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: InfurnusTheme.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Switch between Phone & Email
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: session.busy
                    ? null
                    : () {
                        setState(() {
                          _useEmail = !_useEmail;
                          _identifier.clear();
                          _clientValidationMessage = null;
                        });
                      },
                child: Text(
                  _useEmail ? 'Sign in with Mobile Number' : 'Sign in with Email',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: InfurnusTheme.greenDark,
                  ),
                ),
              ),
            ),

            // Error display
            if (_clientValidationMessage != null || session.error != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: InfurnusTheme.dangerRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _clientValidationMessage ?? session.error!,
                        style: GoogleFonts.inter(color: InfurnusTheme.dangerRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Primary Send OTP / Log In Button (Black rounded button)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: InfurnusTheme.buttonBlack,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: session.busy ? null : () => _validateAndSubmit(session),
              child: session.busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),

            // Debug Preview Dashboard Button (Directly below Send OTP)
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade800, width: 1.5),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.bug_report),
                label: const Text('Preview Dashboard (Testing Only)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: session.busy
                    ? null
                    : () {
                        session.enablePreview();
                        context.go('/driver/dashboard');
                      },
              ),
            ],

            const SizedBox(height: 16),

            // Terms and Conditions text
            Text(
              'By continuing, you agree to our Terms & Conditions and Privacy Policy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: InfurnusTheme.textMuted,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Google Sign In Button
            GoogleSignInButton(
              enabled: !session.busy,
              onIdToken: (token) async {
                await session.authenticateGoogle(token);
                if (context.mounted && session.authenticated) {
                  context.go(session.landingPath);
                }
              },
            ),

            const SizedBox(height: 8),

            // Create account button
            TextButton(
              onPressed: session.busy ? null : () => context.go('/register'),
              child: Text(
                'Create a Driver account',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: InfurnusTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

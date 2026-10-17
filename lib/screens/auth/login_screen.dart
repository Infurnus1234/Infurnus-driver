import 'package:flutter/foundation.dart' show kReleaseMode;
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
  bool _rememberMe = true;
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
            : 'Please enter your phone number.';
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background graphic / gradient matching Zomato welcome feel
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.85), Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/welcome');
                            }
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    const InfurnusLogo(iconSize: 48, fontSize: 26, showSubtitle: true),
                    const SizedBox(height: 20),
                    Text(
                      'INDIA’S #1 FLEET\nDELIVERY & RIDE APP',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet / Card overlay matching Zomato's design in user screenshot
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Log in or sign up',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: InfurnusTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Phone or Email Input Container
                      if (!_useEmail)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
                                    hintText: 'Enter Phone Number',
                                    hintStyle: TextStyle(color: InfurnusTheme.textMuted),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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

                      const SizedBox(height: 10),

                      // Remember my login checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: InfurnusTheme.dangerRed,
                              onChanged: (v) => setState(() => _rememberMe = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remember my login for faster sign-in',
                              style: GoogleFonts.inter(fontSize: 12, color: InfurnusTheme.textDark),
                            ),
                          ),
                          TextButton(
                            onPressed: session.busy
                                ? null
                                : () => setState(() {
                                    _useEmail = !_useEmail;
                                    _identifier.clear();
                                  }),
                            child: Text(
                              _useEmail ? 'Use Phone' : 'Use Email',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: InfurnusTheme.dangerRed),
                            ),
                          ),
                        ],
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

                      const SizedBox(height: 14),

                      // Primary Continue Button (Zomato Style Red/Primary Button)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: InfurnusTheme.dangerRed,
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
                            : Text(
                                'Continue',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),

                      // Debug Preview Dashboard Button
                      if (!kReleaseMode) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade800, width: 1.5),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.bug_report, size: 18),
                          label: const Text('🐛 Preview Dashboard (Testing Only)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: session.busy
                              ? null
                              : () {
                                  session.enablePreview();
                                  context.go('/driver/dashboard');
                                },
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      // Google Sign In & Create Account
                      GoogleSignInButton(
                        label: 'Sign in with Google',
                        enabled: !session.busy,
                        onIdToken: (token) async {
                          await session.authenticateGoogle(token);
                          if (context.mounted && session.authenticated) {
                            context.go(session.landingPath);
                          }
                        },
                      ),

                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: session.busy ? null : () => context.go('/register'),
                        child: Text(
                          'Create a Driver account',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: InfurnusTheme.textDark,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Terms, Privacy & Content Policy Footer matching Zomato mockup
                      Text(
                        'By continuing, you agree to our Terms of Service, Privacy Policy & Content Policy',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: InfurnusTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/driver_session.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  bool _rememberMe = true;
  bool _useEmail = false;
  String? _clientValidationMessage;
  bool _testOnboardingAvailable = false;

  @override
  void initState() {
    super.initState();
    context.read<DriverSession>().api.testOnboardingAvailable().then((enabled) {
      if (mounted) setState(() => _testOnboardingAvailable = enabled);
    });
  }

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  void _validateAndSubmit(DriverSession session) async {
    setState(() => _clientValidationMessage = null);
    final rawInput = _identifier.text.trim();

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

    final fullIdentifier = !_useEmail && !rawInput.contains('@') && !rawInput.startsWith('+')
        ? '+91$rawInput'
        : rawInput;

    final success = await session.login(fullIdentifier, 'InfurnusOTPLogin@123');
    if (!mounted) return;
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
          // Top Poster Artwork Background (No extra logo widget)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_background.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Row(
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
                ),
              ],
            ),
          ),

          // Single Clean White Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
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

                      const SizedBox(height: 12),

                      // Remember my login checkbox
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: InfurnusTheme.primaryGreen,
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
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: InfurnusTheme.primaryGreen),
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

                      const SizedBox(height: 12),

                      // Primary Continue Button
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
                                    'Continue',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),

                      // Debug Preview Dashboard Button
                      if (_testOnboardingAvailable)
                        TextButton(
                          onPressed: session.busy ? null : () async {
                            final ok = await session.startTestOnboarding();
                            if (context.mounted && ok) context.go('/onboarding');
                          },
                          child: const Text('Onboarding Without Login'),
                        ),
                      if (!kReleaseMode) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: InfurnusTheme.primaryGreen,
                            side: const BorderSide(color: InfurnusTheme.primaryGreen, width: 1.5),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: session.busy
                              ? null
                              : () {
                                  session.enablePreview();
                                  context.go('/driver/dashboard');
                                },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bug_report, size: 18, color: InfurnusTheme.primaryGreen),
                              const SizedBox(width: 6),
                              const Icon(Icons.phone, size: 16, color: InfurnusTheme.primaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                'Preview Dashboard (Testing Only)',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: InfurnusTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

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

                      const SizedBox(height: 8),
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

                      const SizedBox(height: 10),

                      // Terms & Privacy footer
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

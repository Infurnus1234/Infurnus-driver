import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../core/operations_theme.dart';

/// A single OTP digit box.
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool filled;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.filled,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? Theme.of(context).colorScheme.error
        : filled
        ? Ops.actionPrimary
        : const Color(0xFFCBD5E1);
    final bgColor = hasError
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.07)
        : filled
        ? const Color(0xFFF0FDF4)
        : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: filled || hasError ? 2 : 1.2),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Ops.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _digitCount = 6;

  final _controllers = List.generate(
    _digitCount,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_digitCount, (_) => FocusNode());

  Timer? _timer;
  bool _submitting = false;
  bool _hasError = false;

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _complete => _otp.length == _digitCount;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Listen to each box and advance focus automatically.
    for (var i = 0; i < _digitCount; i++) {
      final idx = i;
      _controllers[idx].addListener(() => _onDigitChanged(idx));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int idx) {
    if (!mounted) return;
    final text = _controllers[idx].text;
    if (text.isEmpty && idx > 0) {
      // User deleted the digit; move focus back to the previous box.
      _focusNodes[idx - 1].requestFocus();
    } else if (text.length == 1 && idx < _digitCount - 1) {
      _focusNodes[idx + 1].requestFocus();
    }
    // If the user pasted a full 6-digit string into the first box, spread it.
    if (text.length > 1 && idx == 0) {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _digitCount && i < digits.length; i++) {
        _controllers[i].text = digits[i];
        _controllers[i].selection = TextSelection.collapsed(offset: 1);
      }
      final last = (digits.length - 1).clamp(0, _digitCount - 1);
      _focusNodes[last].requestFocus();
    }
    setState(() => _hasError = false);
  }

  Future<void> _verify(DriverSession session) async {
    if (_submitting || session.busy || !_complete) return;
    setState(() {
      _submitting = true;
      _hasError = false;
    });
    try {
      final signup = session.signupId != null;
      final ok = await session.verify(_otp);
      if (mounted && ok && session.authenticated) {
        context.go(signup ? '/onboarding' : session.landingPath);
      } else if (mounted && !ok) {
        setState(() => _hasError = true);
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes.first.requestFocus();
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
    final contact = session.verificationContact ?? 'your registered contact';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Ops.textPrimary,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy
              ? null
              : () => context.go(signup ? '/register' : '/login'),
        ),
        title: Text(
          signup ? 'Verify your account' : 'Verify your identity',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Ops.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon badge
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 30,
                        color: Ops.actionPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Center(
                    child: Text(
                      'Enter verification code',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Ops.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle with masked contact
                  Center(
                    child: Text(
                      active ? 'We sent a 6-digit code to $contact' : 'Start signup or login to request a verification code.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Ops.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  if (!signup) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Login codes are sent only to registered accounts. If you have not signed up in this environment, create an account first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Ops.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go('/role-selection'),
                        child: const Text('Create an account'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 6 OTP boxes
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _digitCount; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              filled: _controllers[i].text.isNotEmpty,
                              hasError: _hasError,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Expired notice
                  if (expired) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Text(
                        'This code has expired. Go back and start signup again.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],

                  // Error from server
                  if (session.error != null || _hasError) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                session.error ??
                                    'Incorrect code. Please try again.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Verify button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Ops.actionPrimary,
                        disabledBackgroundColor: Ops.actionPrimary.withValues(
                          alpha: 0.35,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: active && !busy && !expired && _complete
                          ? () => _verify(session)
                          : null,
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        remaining > 0
                            ? 'Resend in ${remaining}s'
                            : "Didn't receive a code?",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Ops.textSecondary,
                        ),
                      ),
                      if (remaining <= 0) ...[
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: !active || busy || expired
                              ? null
                              : () async {
                                  if (_submitting) return;
                                  setState(() => _submitting = true);
                                  try {
                                    final ok = await session.resend();
                                    if (ok && context.mounted) {
                                      for (final c in _controllers) {
                                        c.clear();
                                      }
                                      _focusNodes.first.requestFocus();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Verification code request accepted.',
                                              ),
                                            ),
                                          );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _submitting = false);
                                    }
                                  }
                                },
                          child: const Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Ops.actionPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Change details link
                  Center(
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => context.go(signup ? '/register' : '/login'),
                      child: Text(
                        signup
                            ? 'Change signup details'
                            : 'Change login details',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Ops.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/driver_session.dart';
import '../../widgets/reference_components.dart';
import '../../core/operations_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = TextEditingController();
  int _secondsRemaining = 28;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 28);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_otp.text.length < 6) {
      setState(() {
        _otp.text += digit;
      });
    }
  }

  void _onBackspacePressed() {
    if (_otp.text.isNotEmpty) {
      setState(() {
        _otp.text = _otp.text.substring(0, _otp.text.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();

    return Scaffold(
      backgroundColor: Ops.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Ops.textPrimary),
          onPressed: session.busy ? null : () => context.go('/login'),
        ),
        centerTitle: true,
        title: const InfurnusBrand(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            const SizedBox(height: 12),
            // Screen 3 Header
            Text(
              'OTP Verification',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Ops.success,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verify your number',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Ops.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the 6-digit code sent to your registered contact',
              style: TextStyle(fontSize: 13, color: Ops.textSecondary),
            ),
            const SizedBox(height: 28),

            // 6-digit Boxes UI matching Reference Screen 3
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final hasDigit = _otp.text.length > index;
                final isCurrent = _otp.text.length == index;
                final char = hasDigit ? _otp.text[index] : '';

                return Container(
                  width: (MediaQuery.sizeOf(context).width - 48) / 6 - 6,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? Ops.success
                          : (hasDigit ? Ops.textMuted : Ops.borderSubtle),
                      width: isCurrent ? 2 : 1.2,
                    ),
                    boxShadow: [
                      if (isCurrent)
                        BoxShadow(
                          color: Ops.success.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    char,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Ops.textPrimary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Hidden direct text field for accessibility, keyboard input, and automated testing
            Opacity(
              opacity: 0.0,
              child: SizedBox(
                height: 1,
                child: TextField(
                  controller: _otp,
                  maxLength: 6,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // Resend Countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive code? ",
                  style: TextStyle(fontSize: 13, color: Ops.textSecondary),
                ),
                if (_secondsRemaining > 0)
                  Text(
                    'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Ops.success,
                    ),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: session.busy
                        ? null
                        : () async {
                            final success = await session.resend();
                            if (success) _startTimer();
                          },
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Ops.success,
                      ),
                    ),
                  ),
              ],
            ),

            if (session.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Ops.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.error!,
                        style: TextStyle(color: Ops.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Verify & Continue Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Ops.actionDark,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: session.busy
                  ? null
                  : () async {
                      final signup = session.signupId != null;
                      await session.verify(_otp.text);
                      _otp.clear();
                      if (context.mounted && session.authenticated) {
                        context.go(
                          signup ? '/onboarding' : session.landingPath,
                        );
                      }
                    },
              child: session.busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Reference On-Screen Numeric Keypad (Screen 3)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var i = 1; i <= 9; i++) _keypadButton(i.toString()),
                const SizedBox.shrink(),
                _keypadButton('0'),
                InkWell(
                  onTap: _onBackspacePressed,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Ops.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.backspace_outlined,
                      color: Ops.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _keypadButton(String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Ops.textPrimary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/operations_theme.dart';
import '../providers/driver_session.dart';

/// One accessible text input preserves paste, autofill and leading zeros;
/// the four visual cells are presentation only.
class RidePinDialog extends StatefulWidget {
  final DriverSession session;
  const RidePinDialog({super.key, required this.session});
  @override
  State<RidePinDialog> createState() => _RidePinDialogState();
}

class _RidePinDialogState extends State<RidePinDialog> {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _pin.addListener(_edited);
    _focus.addListener(_focusChanged);
  }

  void _edited() {
    if (mounted) setState(() => _error = null);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Enter all four digits from the passenger.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.session.transition('in_progress', pin: _pin.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _error =
          widget.session.error ??
          'Could not verify this PIN. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Ops.borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Ops.backgroundPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        size: 22,
                        color: Ops.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ride PIN',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: Ops.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close PIN entry',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ask the passenger for their 4-digit PIN.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Ops.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Keep the native text field interactive and readable to assistive technology.
                      TextField(
                        controller: _pin,
                        focusNode: _focus,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        showCursor: false,
                        enableSuggestions: false,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: const TextStyle(color: Colors.transparent),
                        cursorColor: Colors.transparent,
                        decoration: const InputDecoration(
                          labelText: 'Four-digit Ride PIN',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          labelStyle: TextStyle(color: Colors.transparent),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                      IgnorePointer(
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    key: ValueKey('ride-pin-digit-$i'),
                                    decoration: BoxDecoration(
                                      color: i < _pin.text.length
                                          ? const Color(0xFFF0FAF3)
                                          : Ops.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _error != null
                                            ? Ops.error
                                            : _focus.hasFocus &&
                                                  i == _pin.text.length
                                            ? Ops.actionPrimary
                                            : i < _pin.text.length
                                            ? const Color(0xFFB4DEC3)
                                            : Ops.borderSubtle,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: i < _pin.text.length
                                        ? Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _pin.text[i],
                                                style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w600,
                                                  color: Ops.textPrimary,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 9,
                                            height: 2,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC2CCC5),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Ops.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Ops.error,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy || _pin.text.length != 4 ? null : _verify,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: _busy
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Verifying…'),
                          ],
                        )
                      : const Text(
                          'Verify & start ride',
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your trip starts after PIN verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Ops.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

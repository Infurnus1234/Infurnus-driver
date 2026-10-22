import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class DispatchCountdownWidget extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;

  const DispatchCountdownWidget({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });

  @override
  State<DispatchCountdownWidget> createState() =>
      _DispatchCountdownWidgetState();
}

class _DispatchCountdownWidgetState extends State<DispatchCountdownWidget>
    with WidgetsBindingObserver {
  late Timer _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calculateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _calculateRemaining(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _calculateRemaining();
    }
  }

  void _calculateRemaining() {
    if (!mounted) return;
    final diff = widget.expiresAt.difference(DateTime.now()).inSeconds;
    setState(() {
      _remainingSeconds = diff > 0 ? diff : 0;
    });
    if (_remainingSeconds <= 0) {
      _timer.cancel();
      widget.onExpired();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_remainingSeconds / 15.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InfurnusTheme.greenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InfurnusTheme.primaryGreen),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  color: InfurnusTheme.primaryGreen,
                  backgroundColor: Colors.black12,
                  strokeWidth: 3,
                ),
                Text(
                  '$_remainingSeconds',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: InfurnusTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Accept ride request before timeout',
              style: TextStyle(
                color: InfurnusTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

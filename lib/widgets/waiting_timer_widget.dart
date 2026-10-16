import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class WaitingTimerWidget extends StatefulWidget {
  final DateTime arrivalTime;

  const WaitingTimerWidget({
    super.key,
    required this.arrivalTime,
  });

  @override
  State<WaitingTimerWidget> createState() => _WaitingTimerWidgetState();
}

class _WaitingTimerWidgetState extends State<WaitingTimerWidget> with WidgetsBindingObserver {
  late Timer _timer;
  late Duration _elapsed;

  static const int freeWaitingSeconds = 180; // 3 minutes free waiting

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
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
      _updateElapsed();
    }
  }

  void _updateElapsed() {
    if (!mounted) return;
    setState(() {
      _elapsed = DateTime.now().difference(widget.arrivalTime.toLocal());
      if (_elapsed.isNegative) _elapsed = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _elapsed.inSeconds;
    final isFree = totalSeconds < freeWaitingSeconds;
    final remainingFreeSeconds = freeWaitingSeconds - totalSeconds;
    final billableWaitingSeconds = totalSeconds - freeWaitingSeconds;

    final displaySeconds = isFree ? remainingFreeSeconds : billableWaitingSeconds;
    final minutesStr = (displaySeconds ~/ 60).toString().padLeft(2, '0');
    final secondsStr = (displaySeconds % 60).toString().padLeft(2, '0');

    final accruedCharge = isFree ? 0.0 : (billableWaitingSeconds * 2.0 / 60.0);

    final statusColor = isFree ? InfurnusTheme.primaryGreen : Colors.amber.shade800;
    final bgColor = isFree ? InfurnusTheme.greenLight : Colors.amber.shade50;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isFree ? Icons.timer_outlined : Icons.alarm_on_rounded,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFree ? 'Customer Free Waiting Time' : 'Billable Waiting Time (@ ₹2.00/min)',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$minutesStr:$secondsStr',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (!isFree)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+₹${accruedCharge.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
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

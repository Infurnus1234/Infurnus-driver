import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/operations_theme.dart';
import '../services/api_service.dart';

String inr(dynamic paise) {
  final amount = num.tryParse(paise?.toString() ?? '');
  return amount == null
      ? 'Unavailable'
      : NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 2,
        ).format(amount / 100);
}

String inrRupees(dynamic rupees) {
  final value = num.tryParse(rupees?.toString() ?? '');
  return value == null || !value.isFinite ? 'Unavailable' : inr(value * 100);
}

class OpsPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const OpsPanel({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Ops.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Ops.gap),
          child,
        ],
      ),
    ),
  );
}

class OpsEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  const OpsEmpty(this.message, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(icon, size: 32, color: Ops.textMuted),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Ops.textSecondary),
        ),
      ],
    ),
  );
}

class OpsError extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const OpsError(this.message, {super.key, required this.retry});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: OpsPanel(
      title: 'Unable to load',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Ops.error)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

/// Retains data during refresh, exposes errors, and never substitutes sample data.
class ApiPanel extends StatefulWidget {
  final ApiService api;
  final String path;
  final Widget Function(BuildContext, dynamic) builder;
  final bool embedded;
  const ApiPanel({
    super.key,
    required this.api,
    required this.path,
    required this.builder,
    this.embedded = false,
  });
  @override
  State<ApiPanel> createState() => _ApiPanelState();
}

class _ApiPanelState extends State<ApiPanel> {
  dynamic _data;
  String? _error;
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ApiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.api != widget.api) {
      _data = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.request('GET', widget.path);
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Connection unavailable. Please retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      shrinkWrap: widget.embedded,
      padding: widget.embedded
          ? EdgeInsets.zero
          : const EdgeInsets.all(Ops.padding),
      physics: widget.embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      children: [
        if (_busy)
          const LinearProgressIndicator(semanticsLabel: 'Loading server data'),
        if (_error != null) OpsError(_error!, retry: _load),
        if (_data != null) widget.builder(context, _data),
      ],
    ),
  );
}

Future<bool> confirmOperation(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

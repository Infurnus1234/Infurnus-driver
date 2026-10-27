import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Model search deliberately has no sector filter. Service eligibility is
/// validated separately by the backend's category and approval workflow.
class FleetModelField extends StatefulWidget {
  final ApiService api;
  final TextEditingController make;
  final TextEditingController model;
  const FleetModelField({
    super.key,
    required this.api,
    required this.make,
    required this.model,
  });
  @override
  State<FleetModelField> createState() => _FleetModelFieldState();
}

class _FleetModelFieldState extends State<FleetModelField> {
  Timer? _timer;
  int _generation = 0;
  List<Map> _matches = [];
  String? _error;
  void _search(String value) {
    _timer?.cancel();
    final generation = ++_generation;
    _timer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final result = await widget.api.request(
          'GET',
          '/provider/vehicle-models?search=${Uri.encodeQueryComponent(value)}',
        );
        if (!mounted || generation != _generation) return;
        setState(() {
          _matches = (result as List).cast<Map>();
          _error = null;
        });
      } catch (e) {
        if (mounted && generation == _generation) {
          setState(() {
            _matches = [];
            _error = 'Model search failed. Retry by typing again.';
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _search(widget.model.text);
  }

  Future<void> _addMore() async {
    final make = TextEditingController(text: widget.make.text);
    final model = TextEditingController(text: widget.model.text);
    final form = GlobalKey<FormState>();
    String? error;
    bool saving = false;
    final result = await showDialog<Map>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          String? validate(String? text) {
            final value = text?.trim() ?? '';
            if (value.isEmpty) return 'Required';
            if (value.length > 50 ||
                RegExp(r'[<>]').hasMatch(value) ||
                value.runes.any((c) => c < 32 || c == 127)) {
              return 'Use a plain name up to 50 characters';
            }
            return null;
          }

          return AlertDialog(
            title: const Text('Add More vehicle models'),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: make,
                      enabled: !saving,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer / make',
                      ),
                      validator: validate,
                    ),
                    TextFormField(
                      controller: model,
                      enabled: !saving,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Custom model name',
                      ),
                      validator: validate,
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final saved = await widget.api.request(
                            'POST',
                            '/provider/vehicle-models',
                            body: {
                              'make': make.text.trim(),
                              'model': model.text.trim(),
                            },
                          ) as Map;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, saved);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            update(() {
                              saving = false;
                              error = e is ApiException
                                  ? e.message
                                  : 'Could not save model. Please retry.';
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save model'),
              ),
            ],
          );
        },
      ),
    );
    // Dialog text fields remain mounted through the dismissal animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    make.dispose();
    model.dispose();
    if (!mounted || result == null) return;
    widget.make.text = result['make'] as String;
    widget.model.text = result['model'] as String;
    _search(widget.model.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Model saved and selected')));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextFormField(
        controller: widget.model,
        maxLength: 50,
        decoration: const InputDecoration(
          labelText: 'Model *',
          hintText: 'Search or enter a vehicle model',
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        onChanged: _search,
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      for (final item in _matches.take(5))
        ListTile(
          dense: true,
          title: Text('${item['make']} ${item['model']}'.trim()),
          onTap: () {
            ++_generation;
            _timer?.cancel();
            if (item['make'].toString().isNotEmpty) {
              widget.make.text = item['make'] as String;
            }
            widget.model.text = item['model'] as String;
            setState(() => _matches = []);
          },
        ),
      TextButton.icon(
        onPressed: _addMore,
        icon: const Icon(Icons.add),
        label: const Text('Add More'),
      ),
    ],
  );
}

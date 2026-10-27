import 'package:flutter/material.dart';

/// A manually editable ISO date with an accessible calendar action.
class CalendarField extends StatefulWidget {
  final String label, initialValue;
  final TextEditingController? controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  const CalendarField({
    super.key,
    required this.label,
    this.initialValue = '',
    this.controller,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });
  @override
  State<CalendarField> createState() => _CalendarFieldState();
}

class _CalendarFieldState extends State<CalendarField> {
  late final TextEditingController _owned = TextEditingController(
    text: widget.initialValue,
  );
  TextEditingController get controller => widget.controller ?? _owned;
  @override
  void dispose() {
    _owned.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final first = DateTime(1900), last = DateTime(2100, 12, 31);
    final parsed = DateTime.tryParse(controller.text) ?? DateTime.now();
    final initial = parsed.isBefore(first)
        ? first
        : parsed.isAfter(last)
        ? last
        : parsed;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (selected == null || !mounted) return;
    controller.text = selected.toIso8601String().substring(0, 10);
    widget.onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: widget.enabled,
    validator: widget.validator,
    onChanged: widget.onChanged,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: 'Choose ${widget.label}',
        onPressed: widget.enabled ? _pick : null,
        icon: const Icon(Icons.calendar_today, size: 20),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

/// Contact fields come only from the current authenticated assignment response.
class AssignedOwnerDetails extends StatelessWidget {
  final Map? owner;
  const AssignedOwnerDetails({super.key, required this.owner});

  @override
  Widget build(BuildContext context) {
    if (owner == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in const {
          'name': 'Fleet Owner',
          'phone': 'Phone',
          'email': 'Email',
          'businessName': 'Business',
          'businessType': 'Business type',
        }.entries)
          if (owner![field.key]?.toString().trim().isNotEmpty == true)
            Text('${field.value}: ${owner![field.key]}'),
      ],
    );
  }
}

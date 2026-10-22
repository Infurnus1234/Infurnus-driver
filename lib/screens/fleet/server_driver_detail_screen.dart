import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';

class ServerDriverDetailScreen extends StatelessWidget {
  final String id;
  const ServerDriverDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverSession>().api;
    final path = '/provider/drivers/${Uri.encodeComponent(id)}';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet driver'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Documents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ApiPanel(
              api: api,
              path: '$path/profile',
              builder: (context, data) {
                final row = data as Map;
                return OpsPanel(
                  title: '${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'
                      .trim(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in {
                        'verificationStatus': 'Verification',
                        'availability': 'Availability',
                        'licenseNumber': 'Licence',
                        'licenseExpiry': 'Licence expiry',
                        'phone': 'Phone',
                      }.entries)
                        if (row[field.key] != null)
                          ListTile(
                            title: Text(field.value),
                            subtitle: Text(row[field.key].toString()),
                          ),
                    ],
                  ),
                );
              },
            ),
            ApiPanel(
              api: api,
              path: '$path/documents',
              builder: (context, data) => Column(
                children: [
                  if ((data as List).isEmpty)
                    const OpsEmpty('No authorized driver documents.'),
                  for (final row in data)
                    Card(
                      child: ListTile(
                        title: Text(
                          row['documentType']?.toString() ?? 'Document',
                        ),
                        subtitle: Text(
                          '${row['verificationStatus'] ?? row['status'] ?? 'Unknown'}\nExpiry: ${(row['metadata'] as Map?)?['expiresAt'] ?? 'Not supplied'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

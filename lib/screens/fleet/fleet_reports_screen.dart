import 'fleet_revenue_screen.dart';
import '../../widgets/fleet_monthly_finance.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';

String fleetCsvCell(dynamic value) {
  var text = value?.toString() ?? '';
  if (RegExp(r'^[=+\-@\t\r]').hasMatch(text.trimLeft())) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

class FleetReportsScreen extends StatefulWidget {
  const FleetReportsScreen({super.key});
  @override
  State<FleetReportsScreen> createState() => _FleetReportsScreenState();
}

class _FleetReportsScreenState extends State<FleetReportsScreen> {
  String _period = 'All', _status = 'All';
  bool _exporting = false;
  Future<void> _export(List<Map> rows) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final csv = [
      [
        'Ride',
        'Vehicle',
        'Driver',
        'Status',
        'Pickup',
        'Destination',
        'Created',
        'Final fare (INR)',
      ],
      for (final row in rows)
        [
          row['id'],
          row['vehiclePlate'],
          row['driverName'],
          row['status'],
          row['pickupAddress'],
          row['destinationAddress'],
          row['createdAt'],
          row['finalFare'],
        ],
    ].map((row) => row.map(fleetCsvCell).join(',')).join('\r\n');
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export visible fleet trips',
        fileName: 'infurnus-fleet-trips.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The report could not be exported. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverSession>().api;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fleet trips & reports'),
          bottom: const TabBar(
            indicatorPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            tabs: [
              Tab(text: 'Trips'),
              Tab(text: 'Revenue'),
              Tab(text: 'Monthly records'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ApiPanel(
              api: api,
              path: '/fleet/trips?limit=100',
              builder: (context, data) {
                final source = (data as List).whereType<Map>().toList();
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final since = _period == 'Today'
                    ? today
                    : _period == '7 days'
                    ? today.subtract(const Duration(days: 6))
                    : _period == '30 days'
                    ? today.subtract(const Duration(days: 29))
                    : null;
                final rows = source.where((row) {
                  final date = DateTime.tryParse(
                    row['createdAt']?.toString() ?? '',
                  )?.toLocal();
                  final state = row['status']?.toString();
                  final statusMatches =
                      _status == 'All' ||
                      (_status == 'Active'
                          ? !['completed', 'cancelled'].contains(state)
                          : state == _status.toLowerCase());
                  return statusMatches &&
                      (since == null || date != null && !date.isBefore(since));
                }).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final period in [
                          'Today',
                          '7 days',
                          '30 days',
                          'All',
                        ])
                          ChoiceChip(
                            label: Text(period),
                            selected: _period == period,
                            onSelected: (_) => setState(() => _period = period),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final status in [
                          'All',
                          'Active',
                          'Completed',
                          'Cancelled',
                        ])
                          ChoiceChip(
                            label: Text(status),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = status),
                          ),
                      ],
                    ),
                    Text(
                      '${rows.length} trips in this view, from ${source.length} recent trips. Showing up to 100 trips; dates use your local time.',
                    ),
                    OutlinedButton.icon(
                      onPressed: rows.isEmpty || _exporting
                          ? null
                          : () => _export(rows),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export visible trips'),
                    ),
                    if (rows.isEmpty)
                      const OpsEmpty('No fleet trips match these filters.'),
                    for (final row in rows)
                      OpsPanel(
                        title:
                            '${row['vehiclePlate'] ?? 'Vehicle'} · ${row['status']}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  row['pickupAddress']?.toString() ??
                                      'Pickup unavailable',
                                ),
                                const Icon(Icons.arrow_forward, size: 14),
                                Text(
                                  row['destinationAddress']?.toString() ??
                                      'Destination unavailable',
                                ),
                              ],
                            ),
                            Text(
                              'Driver: ${row['driverName'] ?? 'Not provided'}',
                            ),
                            Text('${row['createdAt'] ?? ''}'),
                            Text(
                              row['finalFare'] != null
                                  ? 'Final fare: ${inrRupees(row['finalFare'])}'
                                  : 'Estimated fare: ${inrRupees(row['fareEstimate'])}',
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: FleetRevenuePanel(),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FleetMonthlyFinance(api: api),
            ),
          ],
        ),
      ),
    );
  }
}

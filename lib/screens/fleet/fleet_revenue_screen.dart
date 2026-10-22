import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';

class FleetVehicleRevenueScreen extends StatelessWidget {
  final String vehicleId;
  final String? name;
  const FleetVehicleRevenueScreen({
    super.key,
    required this.vehicleId,
    this.name,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name ?? 'Vehicle revenue')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FleetRevenuePanel(vehicleId: vehicleId),
    ),
  );
}

class FleetRevenuePanel extends StatefulWidget {
  final String? vehicleId;
  const FleetRevenuePanel({super.key, this.vehicleId});
  @override
  State<FleetRevenuePanel> createState() => _FleetRevenuePanelState();
}

class _FleetRevenuePanelState extends State<FleetRevenuePanel> {
  DateTimeRange? _range;
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverSession>().api;
    final path = widget.vehicleId == null
        ? '/fleet/revenue'
        : '/fleet/vehicles/${widget.vehicleId}/revenue';
    final uri = Uri(
      path: path,
      queryParameters: _range == null
          ? null
          : {'from': date(_range!.start), 'to': date(_range!.end)},
    ).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _range == null
                    ? 'All available records'
                    : '${date(_range!.start)} – ${date(_range!.end)}',
              ),
              onPressed: () async {
                final now = DateTime.now();
                final value = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(now.year, now.month, now.day),
                  initialDateRange: _range,
                );
                if (mounted && value != null) setState(() => _range = value);
              },
            ),
            if (_range != null)
              TextButton(
                onPressed: () => setState(() => _range = null),
                child: const Text('Clear dates'),
              ),
          ],
        ),
        ApiPanel(
          key: ValueKey(uri),
          embedded: true,
          api: api,
          path: uri,
          builder: (context, value) {
            final report = value as Map, summary = report['summary'] as Map;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Fleet revenue · ${report['timeZone']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final metric in [
                  ('Today', 'todayRevenuePaise'),
                  ('This month', 'monthRevenuePaise'),
                  ('Selected period total', 'netRevenuePaise'),
                ])
                  OpsPanel(
                    title: metric.$1,
                    child: Text(
                      inr(summary[metric.$2]),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                Text('Gross collected: ${inr(summary['grossRevenuePaise'])}'),
                Text('Refunds: ${inr(summary['refundPaise'])}'),
                Text('${summary['completedJobs']} completed paid rides / jobs'),
                const Text(
                  'Revenue includes completed jobs with captured payments, less successful refunds. Driver payouts and commission are separate.',
                ),
                const SizedBox(height: 16),
                if (widget.vehicleId == null)
                  Text(
                    'By vehicle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (widget.vehicleId == null)
                  for (final row in report['vehicles'] as List)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${row['make']} ${row['model']} · ${row['plateNumber']}',
                        ),
                        subtitle: Text(
                          '${row['sector']} · ${row['category']}\n${row['completedJobs']} completed jobs · Today ${inr(row['todayRevenuePaise'])} · Month ${inr(row['monthRevenuePaise'])}',
                        ),
                        isThreeLine: true,
                        trailing: Text(inr(row['netRevenuePaise'])),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FleetVehicleRevenueScreen(
                              vehicleId: row['vehicleId'] as String,
                              name: row['plateNumber'].toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                if ((report['vehicles'] as List).isEmpty)
                  const OpsEmpty('No owned vehicles yet.'),
                const SizedBox(height: 16),
                Text(
                  'Revenue history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if ((report['history'] as List).isEmpty)
                  const OpsEmpty('No completed paid jobs in this period.'),
                for (final row in report['history'] as List)
                  ListTile(
                    title: Text('${row['kind']} · ${row['earnedAt']}'),
                    trailing: Text(inr(row['netRevenuePaise'])),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

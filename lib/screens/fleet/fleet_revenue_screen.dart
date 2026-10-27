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
    appBar: AppBar(title: Text(name ?? 'Vehicle analytics')),
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
  String? _vehicle;
  String _period = 'all_time', _interval = 'day';
  DateTimeRange? _range;
  int _historyOffset = 0, _vehicleOffset = 0, _trendOffset = 0;
  final Map<String, String> _choices = {};
  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicleId;
  }

  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  void change(VoidCallback action) => setState(() {
    action();
    _historyOffset = 0;
    _vehicleOffset = 0;
    _trendOffset = 0;
  });
  Widget metric(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: ${value ?? 'Unavailable'}'),
  );
  Widget pages(String title, Map p, void Function(int) update) {
    final offset = p['offset'] as int, total = p['total'] as int;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$title  /  ${total == 0 ? 0 : offset + 1} - ${(offset + 25).clamp(0, total)} of $total',
        ),
        IconButton(
          tooltip: 'Previous $title',
          onPressed: offset == 0
              ? null
              : () => setState(() => update((offset - 25).clamp(0, total))),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next $title',
          onPressed: offset + 25 >= total
              ? null
              : () => setState(() => update(offset + 25)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = <String, String>{
      'period': _period,
      'interval': _interval,
      'limit': '25',
      'historyOffset': '$_historyOffset',
      'vehicleOffset': '$_vehicleOffset',
      'trendOffset': '$_trendOffset',
      if (_period == 'custom' && _range != null) 'from': date(_range!.start),
      if (_period == 'custom' && _range != null) 'to': date(_range!.end),
    };
    final uri = Uri(
      path: _vehicle == null
          ? '/fleet/revenue'
          : '/fleet/vehicles/$_vehicle/revenue',
      queryParameters: query,
    ).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fleet analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              isExpanded: true,
              key: const Key('analytics-vehicle'),
              value: _vehicle ?? 'all',
              hint: const Text('Vehicle'),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All vehicles'),
                ),
                for (final e in {
                  ..._choices,
                  if (_vehicle != null && !_choices.containsKey(_vehicle))
                    _vehicle!: 'Selected vehicle',
                }.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => change(() => _vehicle = v == 'all' ? null : v),
            ),
            DropdownButton<String>(
              isExpanded: true,
              key: const Key('analytics-period'),
              value: _period,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'this_week', child: Text('This week')),
                DropdownMenuItem(
                  value: 'this_month',
                  child: Text('This month'),
                ),
                DropdownMenuItem(value: 'all_time', child: Text('All time')),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('Custom date range'),
                ),
              ],
              onChanged: (v) async {
                if (v == 'custom') {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(now.year, now.month, now.day),
                    initialDateRange: _range,
                  );
                  if (mounted && range != null) {
                    change(() {
                      _range = range;
                      _period = 'custom';
                    });
                  }
                } else if (v != null) {
                  change(() => _period = v);
                }
              },
            ),
            if (_period == 'custom' && _range != null)
              Text('${date(_range!.start)}  -  ${date(_range!.end)}'),
          ],
        ),
        ApiPanel(
          key: ValueKey(uri),
          embedded: true,
          api: context.read<DriverSession>().api,
          path: uri,
          builder: (context, value) {
            final report = (value as Map)['analytics'];
            if (report is! Map) {
              return const OpsEmpty(
                'Analytics unavailable. Update the backend and retry.',
              );
            }
            final s = report['summary'] as Map,
                inventory = report['inventory'] as Map,
                pagination = report['pagination'] as Map,
                period = report['period'] as Map;
            final vehicles = report['vehicles'] as List,
                history = report['history'] as List,
                trends = report['trends'] as List;
            var choicesChanged = false;
            for (final v in vehicles) {
              final id = v['vehicleId'] as String;
              final plate = v['plateNumber'].toString();
              if (_choices[id] != plate) {
                _choices[id] = plate;
                choicesChanged = true;
              }
            }
            if (choicesChanged) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_vehicle == null ? 'All vehicles' : _choices[_vehicle] ?? 'Selected vehicle'}  /  ${period['from'] ?? 'Beginning'}  -  ${period['to'] ?? 'All dates'}  /  ${report['timeZone']}',
                ),
                const Text(
                  'Activity by completion date. Inventory is current, independent of the reporting period.',
                ),
                OpsPanel(
                  title: 'Current inventory',
                  child: Wrap(
                    spacing: 16,
                    children: [
                      metric('Vehicles', inventory['total']),
                      metric('Active', inventory['active']),
                      metric('Inactive', inventory['inactive']),
                      metric('Operating', inventory['operating']),
                    ],
                  ),
                ),
                OpsPanel(
                  title: 'Trips in selected period',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metric('Completed trips / jobs', s['completedTrips']),
                      metric('Cancelled', s['cancelledTrips']),
                      metric(
                        'Cancellation rate (%)',
                        s['cancellationRatePercent'],
                      ),
                      metric(
                        'Completed today (within selection)',
                        s['completedToday'],
                      ),
                      metric(
                        'Completed this week (within selection)',
                        s['completedThisWeek'],
                      ),
                      metric(
                        'Completed this month (within selection)',
                        s['completedThisMonth'],
                      ),
                      metric(
                        'Average trips per vehicle',
                        s['averageTripsPerVehicle'],
                      ),
                      for (final row in report['status'] as List)
                        metric('Status: ${row['status']}', row['count']),
                    ],
                  ),
                ),
                OpsPanel(
                  title: 'Financial breakdown  /  INR',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metric(
                        'Known gross completed trip fares',
                        inr(s['grossFarePaise']),
                      ),
                      metric('Missing final fares', s['missingFareTrips']),
                      metric(
                        'Average collected per completed trip',
                        inr(s['averageCollectedPerCompletedTripPaise']),
                      ),
                      metric(
                        'Captured customer payments',
                        inr(s['capturedPaise']),
                      ),
                      metric(
                        'Successful refunds / full reversals',
                        inr(s['refundPaise']),
                      ),
                      metric(
                        'Collected after refunds',
                        inr(s['collectedAfterRefundsPaise']),
                      ),
                      metric(
                        'Recorded ride commissions',
                        inr(s['recordedRideCommissionPaise']),
                      ),
                      metric(
                        'Commission-covered trips',
                        s['commissionCoveredTrips'],
                      ),
                      metric(
                        'Pending payment attempts',
                        inr(s['pendingAttemptPaise']),
                      ),
                      metric(
                        'Failed payment attempts',
                        inr(s['failedAttemptPaise']),
                      ),
                      metric(
                        'Average gross fare per priced trip',
                        inr(s['averageGrossFarePaise']),
                      ),
                      metric(
                        'Fleet Owner net earnings',
                        inr(s['ownerNetEarningsPaise']),
                      ),
                      metric('Settled to owner', inr(s['settledPaise'])),
                      const Text(
                        'Captured payments are not settled owner earnings. Pending/failed attempts are not balances due.',
                      ),
                    ],
                  ),
                ),
                OpsPanel(
                  title: 'Measured operations',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metric(
                        'Known distance (metres)',
                        s['knownDistanceMeters'],
                      ),
                      metric('Trips with distance', s['distanceCoveredTrips']),
                      metric(
                        'Known operating time (seconds)',
                        s['knownOperatingSeconds'],
                      ),
                      metric('Trips with measured time', s['timeCoveredTrips']),
                      const Text(
                        'Partial measured totals only. Missing measurements, zero defaults and scheduled rental time are not estimated.',
                      ),
                    ],
                  ),
                ),
                if (inventory['total'] == 0)
                  const OpsEmpty('No owned vehicles yet.'),
                if (s['totalJobs'] == 0)
                  const OpsEmpty('No recorded trips in this period.'),
                const SizedBox(height: 12),
                const Text('Vehicle contributions'),
                for (final row in vehicles)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${row['plateNumber']}  /  ${row['make']} ${row['model']}',
                      ),
                      subtitle: Text(
                        '''${row['active'] == true ? 'Active' : 'Inactive'}  /  ${row['completedTrips']} completed
Gross fares ${inr(row['grossFarePaise'])}  /  Collected ${inr(row['collectedAfterRefundsPaise'])}
Assigned driver: ${row['assignedDriverId'] == null ? 'Unassigned' : '${row['assignedDriverFirstName'] ?? ''} ${row['assignedDriverLastName'] ?? ''}'}''',
                      ),
                      onTap: () =>
                          change(() => _vehicle = row['vehicleId'] as String),
                    ),
                  ),
                pages(
                  'Vehicles',
                  pagination['vehicles'] as Map,
                  (v) => _vehicleOffset = v,
                ),
                Wrap(
                  spacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Performance trends'),
                    DropdownButton<String>(
                      value: _interval,
                      items: const [
                        DropdownMenuItem(value: 'day', child: Text('Daily')),
                        DropdownMenuItem(value: 'week', child: Text('Weekly')),
                        DropdownMenuItem(
                          value: 'month',
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) change(() => _interval = v);
                      },
                    ),
                  ],
                ),
                for (final row in trends)
                  ListTile(
                    title: Text(row['date'].toString()),
                    subtitle: Text(
                      '${row['completedTrips']} completed  /  Gross ${inr(row['grossFarePaise'])}  /  Collected ${inr(row['collectedAfterRefundsPaise'])}',
                    ),
                  ),
                pages(
                  'Trend periods',
                  pagination['trends'] as Map,
                  (v) => _trendOffset = v,
                ),
                const Text('Trip history'),
                for (final row in history)
                  ListTile(
                    title: Text('${row['kind']}  /  ${row['id']}'),
                    subtitle: Text(
                      '''${row['activityAt']}  /  ${row['status']}
Fare ${inr(row['farePaise'])}  /  Captured ${inr(row['capturedPaise'])}  /  Refund ${inr(row['refundPaise'])}
${row['paymentAttempts']} payment attempts; pending ${inr(row['pendingAttemptPaise'])}, failed ${inr(row['failedAttemptPaise'])}''',
                    ),
                  ),
                pages(
                  'Trips',
                  pagination['history'] as Map,
                  (v) => _historyOffset = v,
                ),
                ExpansionTile(
                  title: const Text('Data coverage and unavailable metrics'),
                  children: [
                    for (final e in (report['availability'] as Map).entries)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${e.key}: ${e.value}'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

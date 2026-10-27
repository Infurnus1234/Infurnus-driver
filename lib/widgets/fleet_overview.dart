import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../core/operations_theme.dart';
import '../providers/provider_assets.dart';
import '../services/api_service.dart';
import 'reference_components.dart';
import 'operations.dart';

class FleetOverview extends StatelessWidget {
  final ProviderAssets assets;
  const FleetOverview({super.key, required this.assets});
  @override
  Widget build(BuildContext context) {
    final activeVehicles = assets.vehicles
        .where((v) => v['isActive'] == true)
        .length;
    final activeDrivers = assets.drivers
        .where(
          (d) =>
              (d['status'] ?? d['membershipStatus'])
                  ?.toString()
                  .toUpperCase() ==
              'ACTIVE',
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Fleet Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in [
                (
                  Icons.directions_car_outlined,
                  'Total Vehicles',
                  assets.vehicles.length,
                ),
                (
                  Icons.local_shipping_outlined,
                  'Active Vehicles',
                  activeVehicles,
                ),
                (Icons.people_outline, 'Total Drivers', assets.drivers.length),
                (Icons.badge_outlined, 'Active Drivers', activeDrivers),
              ])
                SizedBox(
                  width: box.maxWidth < 280
                      ? box.maxWidth
                      : (box.maxWidth - 10) / 2,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Ops.surfaceOverlay,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              metric.$1,
                              size: 20,
                              color: Ops.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${metric.$3}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  metric.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Ops.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FleetRevenueSummary(api: assets.api),
        if ((assets.earnings?['days'] as List? ?? []).isNotEmpty)
          OpsPanel(
            title: 'Daily settlement net',
            child: SettlementBars(
              rows: (assets.earnings!['days'] as List)
                  .whereType<Map>()
                  .toList(),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => context.push('/fleet/reports'),
          icon: const Icon(Icons.bar_chart),
          label: const Text('Revenue & reports'),
        ),
      ],
    );
  }
}

class FleetRevenueSummary extends StatefulWidget {
  final ApiService api;
  const FleetRevenueSummary({super.key, required this.api});
  @override
  State<FleetRevenueSummary> createState() => _FleetRevenueSummaryState();
}

class _FleetRevenueSummaryState extends State<FleetRevenueSummary> {
  late Future<dynamic> _report;
  @override
  void initState() {
    super.initState();
    _report = widget.api.request('GET', '/fleet/earnings');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _report,
    builder: (context, snapshot) => OpsPanel(
      title: 'Revenue · this month',
      child: snapshot.connectionState != ConnectionState.done
          ? const LinearProgressIndicator()
          : snapshot.hasError
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue is unavailable right now.'),
                TextButton(
                  onPressed: () => setState(
                    () =>
                        _report = widget.api.request('GET', '/fleet/earnings'),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inrRupees((snapshot.data as Map)['thisMonthRevenue']),
                  style: Ops.metric,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Net revenue from completed paid jobs',
                  style: TextStyle(color: Ops.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(snapshot.data as Map)['totalTrips'] ?? '—'} completed trips in total',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
    ),
  );
}

class FleetLocationMap extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const FleetLocationMap({super.key, required this.rows});
  @override
  State<FleetLocationMap> createState() => _FleetLocationMapState();
}

class _FleetLocationMapState extends State<FleetLocationMap> {
  bool? _configured;
  String _filter = 'All';
  String? _selectedId;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    var configured = false;
    try {
      configured =
          await const MethodChannel('infurnus/maps')
              .invokeMethod<bool>('configured') ??
          false;
    } on PlatformException {
      configured = false;
    } on MissingPluginException {
      configured = false;
    }
    if (mounted) setState(() => _configured = configured);
  }

  LatLng? _point(Map row) {
    final lat = num.tryParse(row['latitude'].toString()),
        lng = num.tryParse(row['longitude'].toString());
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  LatLng? _tripPoint(Map row, String stop) {
    final trip = row['trip'];
    return trip is Map
        ? _point({
            'latitude': trip['${stop}Latitude'],
            'longitude': trip['${stop}Longitude'],
          })
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows
        .where(
          (r) =>
              _filter == 'All' ||
              (_filter == 'Recent' ? r['stale'] == false : r['stale'] != false),
        )
        .toList();
    final points = rows.where((r) => _point(r) != null).toList();
    final selected = rows
        .where((r) => r['driverProfileId'] == _selectedId)
        .firstOrNull;
    return OpsPanel(
      title: 'Fleet locations · last reported',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final filter in ['All', 'Recent', 'Stale'])
                ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
            ],
          ),
          if (_configured == null) const LinearProgressIndicator(),
          if (_configured == false)
            const OpsEmpty(
              'Live map is unavailable in this build. Location records remain available below.',
              icon: Icons.map_outlined,
            ),
          if (_configured == true && points.isNotEmpty)
            SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _point(points.first)!,
                  zoom: 12,
                ),
                mapToolbarEnabled: false,
                markers: {
                  if (selected != null)
                    for (final stop in ['origin', 'destination'])
                      if (_tripPoint(selected, stop) != null)
                        Marker(
                          markerId: MarkerId('trip:$stop'),
                          position: _tripPoint(selected, stop)!,
                          infoWindow: InfoWindow(
                            title: stop == 'origin'
                                ? 'Trip pickup'
                                : 'Trip destination',
                            snippet: selected['trip'][stop]?.toString(),
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            stop == 'origin'
                                ? BitmapDescriptor.hueAzure
                                : BitmapDescriptor.hueRed,
                          ),
                        ),
                  for (final row in points)
                    Marker(
                      markerId: MarkerId(row['driverProfileId'].toString()),
                      position: _point(row)!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        row['stale'] == false
                            ? BitmapDescriptor.hueGreen
                            : BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: InfoWindow(
                        title: row['plateNumber']?.toString() ?? 'Driver',
                        snippet:
                            '${row['stale'] == false ? 'Recent' : 'Stale'} · ${row['recordedAt'] ?? 'Time unknown'}',
                      ),
                      onTap: () => setState(
                        () => _selectedId = row['driverProfileId'].toString(),
                      ),
                    ),
                },
              ),
            ),
          if (points.isEmpty) const OpsEmpty('No coordinates in this view.'),
          if (selected?['trip'] is Map)
            ListTile(
              title: Text('Trip: ${selected!['trip']['status']}'),
              subtitle: Text(
                '${selected['trip']['origin'] ?? 'Pickup unavailable'} to ${selected['trip']['destination'] ?? 'Destination unavailable'}',
              ),
            ),
          if (selected != null)
            ListTile(
              title: Text(selected['plateNumber']?.toString() ?? 'Driver'),
              subtitle: Text(
                '${selected['availability']} · ${selected['recordedAt'] ?? 'Time unknown'}',
              ),
            ),
          const Text(
            'Green: recently reported · Amber: stale or unknown. Locations refresh with fleet data; this is not continuous streaming.',
            style: TextStyle(color: Ops.textSecondary),
          ),
        ],
      ),
    );
  }
}

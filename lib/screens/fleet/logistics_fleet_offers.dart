import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';

class LogisticsFleetOffers extends StatefulWidget {
  const LogisticsFleetOffers({super.key, required this.revision});

  final int revision;

  @override
  State<LogisticsFleetOffers> createState() => _LogisticsFleetOffersState();
}

class _LogisticsFleetOffersState extends State<LogisticsFleetOffers> {
  static const _endpoint = '/provider/logistics-dispatch';
  List<Map> _offers = [];
  Timer? _refreshTimer;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_busy) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() => _run(() async {});

  String _pickupTarget(Map offer) {
    if (!['pending', 'coordinating', 'forwarded'].contains(offer['status'])) {
      return '';
    }
    final deadline = DateTime.tryParse(offer['deadline']?.toString() ?? '');
    final serverTime = DateTime.tryParse(offer['serverTime']?.toString() ?? '');
    if (deadline == null || serverTime == null) return '';
    final seconds = deadline.difference(serverTime).inSeconds;
    return seconds <= 0
        ? '\nPickup target passed'
        : '\nPickup target in ${(seconds / 60).ceil()} min';
  }

  @override
  void didUpdateWidget(covariant LogisticsFleetOffers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final api = context.read<DriverSession>().api;
    if (api.accessToken == null || !api.hasFleetRole) return;
    setState(() => _busy = true);
    try {
      await action();
      final offers = await api.request('GET', _endpoint) as List;
      if (!mounted) return;
      setState(() {
        _offers = offers.cast<Map>();
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(Map offer, bool accept) => _run(() async {
    final session = context.read<DriverSession>();
    await session.api.request(
      'POST',
      "$_endpoint/${offer['id']}/respond",
      body: {'accept': accept},
    );
    await session.notifications?.dismissLogisticsOffer(
      offer['rideId'] as String,
    );
  });

  Future<void> _chooseDriver(String id) => _run(() async {
    final api = context.read<DriverSession>().api;
    final candidates =
        await api.request('GET', '$_endpoint/$id/candidates') as List;
    if (!mounted) return;
    final selected = await showDialog<Map>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Choose a driver and vehicle'),
        children: [
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No eligible drivers and vehicles are available.'),
            ),
          for (final candidate in candidates.cast<Map>())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, candidate),
              child: Text(
                "${candidate['name']} · ${candidate['category']} · "
                "${((candidate['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km",
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await api.request(
      'POST',
      '$_endpoint/$id/forward',
      body: {
        'driverId': selected['driverId'],
        'vehicleId': selected['vehicleId'],
      },
    );
  });

  @override
  Widget build(BuildContext context) {
    if (_offers.isEmpty && _error == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logistics requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_error != null) Text(_error!),
            for (final offer in _offers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${offer['bookingId'] ?? offer['rideId']} · ${offer['category']}",
                ),
                subtitle: Text(
                  "${offer['pickup'] ?? 'Pickup address unavailable'}\n"
                  "${offer['status']}${offer['driverResponse'] == null ? '' : ' · Driver: ${offer['driverResponse']}'}"
                  "${_pickupTarget(offer)}",
                ),
                trailing: offer['status'] == 'pending'
                    ? PopupMenuButton<bool>(
                        enabled: !_busy,
                        onSelected: (accept) =>
                            unawaited(_respond(offer, accept)),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: true,
                            child: Text('Accept coordination'),
                          ),
                          PopupMenuItem(value: false, child: Text('Reject')),
                        ],
                      )
                    : offer['status'] == 'coordinating'
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _chooseDriver(offer['id'] as String),
                        child: const Text('Select driver'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

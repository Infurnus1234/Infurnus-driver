import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/operations_theme.dart';
import '../models/route_geometry.dart';
import '../providers/driver_session.dart';
import '../services/api_service.dart';
import 'operations.dart';

class TripMap extends StatefulWidget {
  final bool compact;
  const TripMap({super.key, this.compact = false});
  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  GoogleMapController? _controller;
  List<LatLng> _route = [];
  String? _error, _tripKey;
  Map? _metrics;
  bool _loading = false;
  bool? _configured;
  int _generation = 0;
  LatLng? _point(dynamic input) {
    if (input is! Map) return null;
    final lat = num.tryParse(input['latitude'].toString());
    final lng = num.tryParse(input['longitude'].toString());
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

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    bool configured;
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

  Future<void> _load(DriverSession session, LatLng target) async {
    if (_loading || session.position == null) return;
    if (DateTime.now().difference(session.position!.timestamp) >
        const Duration(minutes: 2)) {
      setState(() {
        _error = 'Waiting for a fresh GPS position before routing.';
        _route = [];
        _metrics = null;
      });
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _route = [];
      _metrics = null;
    });
    try {
      final position = session.position!;
      final data = await session.api.request(
        'POST',
        '/maps/route',
        body: {
          'origin': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'destination': {
            'latitude': target.latitude,
            'longitude': target.longitude,
          },
          'mode': 'driving',
          'avoidTolls': false,
        },
      ) as Map;
      final points = decodeRoutePolyline(
        data['encodedPolyline']?.toString() ?? '',
      );
      if (mounted && generation == _generation) {
        setState(() {
          _metrics = data;
          _route = points.map((p) => LatLng(p[0], p[1])).toList();
        });
        _fit();
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Road route unavailable. Retry when connected.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _fit() async {
    if (_route.length < 2 || _controller == null) return;
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final p in _route) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        36,
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final trip = session.currentTrip;
    final pickup = _point(trip?['pickup']);
    final destination =
        trip?['pinVerified'] == true && trip?['status'] == 'in_progress'
        ? _point(trip?['destination'])
        : null;
    final target = trip?['status'] == 'in_progress' ? destination : pickup;
    final position = session.position;
    final stale =
        position != null &&
        DateTime.now().difference(position.timestamp) >
            const Duration(minutes: 2);
    final current = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    final key =
        '${trip?['id']}:${trip?['status']}:${current?.latitude.toStringAsFixed(3)}:${current?.longitude.toStringAsFixed(3)}:$stale';
    if (key != _tripKey) {
      _tripKey = key;
      // Invalidate a response for the previous trip or navigation stage.
      _generation++;
      _loading = false;
      _route = [];
      _metrics = null;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (target != null && current != null) {
          _load(session, target);
        } else {
          setState(() {
            _route = [];
            _metrics = null;
          });
        }
      });
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact && trip != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              trip['status'] == 'in_progress'
                  ? Icons.location_on_outlined
                  : Icons.trip_origin,
              color: trip['status'] == 'in_progress' ? Ops.error : Ops.success,
            ),
            title: Text(
              trip['status'] == 'in_progress' ? 'Drop off' : 'Pickup',
              style: const TextStyle(color: Ops.textSecondary, fontSize: 11),
            ),
            subtitle: Text(
              (trip['status'] == 'in_progress'
                          ? trip['destinationAddress']
                          : trip['pickupAddress'])
                      ?.toString() ??
                  'Address unavailable',
              style: const TextStyle(
                color: Ops.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_configured == null) const LinearProgressIndicator(),
        if (_configured == false)
          const OpsEmpty(
            'Map is unavailable on this build. Location and trip updates remain available.',
            icon: Icons.map_outlined,
          ),
        if (_configured == true)
          SizedBox(
            height: widget.compact ? 330 : 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: current ?? pickup ?? const LatLng(25.5941, 85.1376),
                  zoom: 13,
                ),
                onMapCreated: (controller) {
                  _controller = controller;
                  _fit();
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: true,
                markers: {
                  if (current != null)
                    Marker(
                      markerId: const MarkerId('driver'),
                      position: current,
                      infoWindow: InfoWindow(
                        title: stale
                            ? 'Last known GPS position (stale)'
                            : 'GPS position',
                        snippet: position!.timestamp.toIso8601String(),
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        stale
                            ? BitmapDescriptor.hueOrange
                            : BitmapDescriptor.hueGreen,
                      ),
                    ),
                  if (pickup != null)
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: pickup,
                      infoWindow: const InfoWindow(title: 'Pickup'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                  if (destination != null)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: destination,
                      infoWindow: const InfoWindow(title: 'Destination'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                },
                polylines: {
                  if (_route.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('road'),
                      points: _route,
                      color: trip?['status'] == 'in_progress'
                          ? Ops.actionPrimary
                          : Ops.actionDark,
                      width: 5,
                    ),
                },
              ),
            ),
          ),
        if (current == null)
          const Text(
            'Location unavailable. Enable GPS and allow location access.',
          ),
        if (position != null && !widget.compact)
          Text(
            'GPS accuracy ±${position.accuracy.toStringAsFixed(0)} m · ${position.timestamp.toLocal()}',
          ),
        if (session.lastLocationSent != null && !widget.compact)
          Text('Last server delivery: ${session.lastLocationSent!.toLocal()}'),
        if (_loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Calculating road route',
          ),
        if (_metrics != null)
          Text(
            '${((_metrics!['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km · ${((_metrics!['durationSeconds'] as num) / 60).ceil()} min estimated',
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Ops.error)),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: session.busy
                  ? null
                  : () async {
                      final ok = await session.locate();
                      if (ok && session.position != null) {
                        _controller?.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(
                              session.position!.latitude,
                              session.position!.longitude,
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.my_location),
              label: const Text('Locate me'),
            ),
            if (target != null)
              OutlinedButton.icon(
                onPressed: _loading || current == null
                    ? null
                    : () => _load(session, target),
                icon: const Icon(Icons.route),
                label: const Text('Refresh route'),
              ),
          ],
        ),
      ],
    );
    return widget.compact
        ? Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: const EdgeInsets.all(12), child: content),
          )
        : OpsPanel(
            title: trip == null ? 'Your location' : 'Trip route',
            child: content,
          );
  }
}

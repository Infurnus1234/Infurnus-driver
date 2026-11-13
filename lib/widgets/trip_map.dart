import 'ride_map_phase.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/operations_theme.dart';
import '../models/route_geometry.dart';
import '../providers/driver_session.dart';
import '../services/api_service.dart';
import 'operations.dart';
import 'vehicle_motion.dart';
import 'map_camera_queue.dart';

class TripMap extends StatefulWidget {
  final bool compact;
  final bool fullScreen;
  final double bottomInset;
  final VoidCallback? onMapTap;
  const TripMap({
    super.key,
    this.compact = false,
    this.fullScreen = false,
    this.bottomInset = 0,
    this.onMapTap,
  });
  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> with SingleTickerProviderStateMixin {
  late final VehicleMotion _motion;
  BitmapDescriptor? _arrow;
  bool _follow = true;
  DateTime? _lastRouteAttempt;
  DateTime? _offRouteSince;
  Timer? _freshnessTimer;
  bool _gpsStale = false;
  GoogleMapController? _controller;
  final _camera = MapCameraQueue();
  List<LatLng> _route = [];
  String? _error, _tripKey;
  Map? _metrics;
  bool _loading = false;
  bool? _configured;
  int _generation = 0;
  int _routeVersion = -1;
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
    _motion = VehicleMotion(this);
    _arrow = cachedNavigationArrow;
    navigationArrow().then((icon) {
      if (mounted) setState(() => _arrow = icon);
    });
    _freshnessTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final stale =
          _motion.timestamp != null &&
          DateTime.now().difference(_motion.timestamp!) >
              const Duration(seconds: 10);
      if (mounted && stale != _gpsStale) setState(() => _gpsStale = stale);
    });
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
    _lastRouteAttempt = DateTime.now();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await session.api.request(
        'GET',
        '/rides/driver/rides/${session.currentTrip!['id']}/map?includeRoute=true',
      ) as Map;
      final data = snapshot['route'];
      if (data is! Map) {
        throw const ApiException(
          'Road route unavailable. Retry when connected.',
        );
      }
      final points = decodeRoutePolyline(
        data['encodedPolyline']?.toString() ?? '',
      );
      if (mounted &&
          generation == _generation &&
          (snapshot['routeVersion'] as num? ?? 0) >= _routeVersion) {
        setState(() {
          _routeVersion = (snapshot['routeVersion'] as num? ?? 0).toInt();
          _metrics = data;
          _route = points.map((p) => LatLng(p[0], p[1])).toList();
        });
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
    _camera.move(
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
    _freshnessTimer?.cancel();
    _motion.dispose();
    _camera.dispose();
    // GoogleMap owns the native controller lifecycle.
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact && _configured == false) {
      return const SizedBox.shrink();
    }
    context.select((DriverSession s) {
      final trip = s.currentTrip;
      final navigation = s.liveNavigation;
      return (
        trip?['id'],
        trip?['status'],
        _point(trip?['pickup']),
        _point(trip?['destination']),
        trip?['pickupAddress'],
        trip?['destinationAddress'],
        s.position,
        s.locationWarning,
        navigation?['segment'],
        navigation?['routeVersion'],
        widget.fullScreen ? null : s.busy,
        widget.fullScreen || widget.compact ? null : s.lastLocationSent,
      );
    });
    final session = context.read<DriverSession>();
    final trip = session.currentTrip;
    final started = rideHasStarted(trip?['status']?.toString());
    final pickup = _point(trip?['pickup']);
    final destination = _point(trip?['destination']);
    final target = started ? destination : pickup;
    final position = session.position;
    final stale =
        position != null &&
        DateTime.now().difference(position.timestamp) >
            const Duration(minutes: 2);
    final current = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    final key =
        "${trip?['id']}:${trip?['status'] == 'in_progress'}:${target?.latitude}:${target?.longitude}";
    if (current != null &&
        _motion.sample(
          current,
          position!.timestamp,
          heading: position.heading,
          speed: position.speed,
          accuracy: position.accuracy,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_follow) {
          _camera.move(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _motion.target ?? current,
                zoom: 17,
                tilt: 45,
                bearing: _motion.heading,
              ),
            ),
          );
        }
        // Route geometry is retained during normal movement. Require sustained deviation and cooldown.
        if (_route.length > 1 && target != null && !_loading) {
          final deviation = VehicleMotion.deviation(current, _route);
          if (deviation < 40) _offRouteSince = null;
          if (deviation > 80) _offRouteSince ??= DateTime.now();
          if (_offRouteSince != null &&
              DateTime.now().difference(_offRouteSince!) >
                  const Duration(seconds: 8) &&
              (_lastRouteAttempt == null ||
                  DateTime.now().difference(_lastRouteAttempt!) >
                      const Duration(seconds: 30))) {
            _offRouteSince = null;
            _load(session, target);
          }
        }
      });
    }
    if (key != _tripKey) {
      _tripKey = key;
      _routeVersion = -1;
      _lastRouteAttempt = null;
      _offRouteSince = null;
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
    if (_route.isEmpty &&
        !_loading &&
        target != null &&
        current != null &&
        !stale &&
        (_lastRouteAttempt == null ||
            DateTime.now().difference(_lastRouteAttempt!) >
                const Duration(seconds: 30))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(session, target);
      });
    }
    final navigation = session.liveNavigation;
    final segment = trip?['status'] == 'in_progress' ? 'destination' : 'pickup';
    if (navigation?['rideId'] == trip?['id'] &&
        navigation?['segment'] == segment &&
        (navigation?['routeVersion'] as num? ?? -1) > _routeVersion) {
      final route = navigation!['route'];
      _routeVersion = (navigation['routeVersion'] as num).toInt();
      if (route is Map &&
          route['distanceMeters'] is num &&
          route['durationSeconds'] is num) {
        try {
          _route = decodeRoutePolyline(
            route['encodedPolyline']?.toString() ?? '',
          ).map((p) => LatLng(p[0], p[1])).toList();
          _metrics = route;
        } on FormatException {
          // Keep the current route if a socket update has unusable geometry.
        }
      }
    }
    final polylines = <Polyline>{
      if (_route.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('road'),
          points: _route,
          color: const Color(0xFF2168F5),
          width: 5,
        ),
    };
    final nativeMap = LayoutBuilder(
      builder: (context, bounds) {
        final top = widget.fullScreen
            ? math.min(
                MediaQuery.paddingOf(context).top +
                    (session.currentTrip?['status'] == 'in_progress'
                        ? 170
                        : 146),
                bounds.maxHeight / 2,
              )
            : 0.0;
        final bottom = math.min(
          widget.bottomInset + 12,
          math.max(0.0, bounds.maxHeight - top - 48),
        );
        return Listener(
          onPointerDown: (_) {
            _follow = false;
            _camera.cancel();
          },
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: current ?? pickup ?? const LatLng(25.5941, 85.1376),
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _controller = controller;
                _camera.controller = controller;
                if (_route.length >= 2) {
                  _fit();
                } else if (_follow) {
                  // Replay GPS received before native map initialization.
                  final fix = _motion.position ?? current;
                  if (fix != null) {
                    _camera.move(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: fix,
                          zoom: 17,
                          tilt: 45,
                          bearing: _motion.heading,
                        ),
                      ),
                    );
                  }
                }
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: !widget.fullScreen,
              onTap: (_) => widget.onMapTap?.call(),
              padding: widget.fullScreen
                  ? EdgeInsets.only(top: top, bottom: bottom)
                  : EdgeInsets.zero,
              markers: {
                if (current != null && _arrow != null)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: _motion.position ?? current,
                    rotation: _motion.heading,
                    flat: true,
                    anchor: const Offset(0.5, 0.5),
                    infoWindow: InfoWindow(
                      title: stale || _gpsStale
                          ? 'Last known GPS position (stale)'
                          : 'GPS position',
                      snippet: position!.timestamp.toIso8601String(),
                    ),
                    icon: _arrow!,
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
              polylines: polylines,
            ),
          ),
        );
      },
    );
    if (widget.fullScreen) {
      final address =
          trip?[started ? 'destinationAddress' : 'pickupAddress']?.toString() ??
          (started ? 'Destination' : 'Pickup');
      final instruction =
          _metrics?['navigationInstruction']?['instructions']?.toString() ??
          (started ? 'Continue to destination' : 'Head to pickup');
      return LayoutBuilder(
        builder: (context, bounds) {
          final top = MediaQuery.paddingOf(context).top + 72;
          final showControls =
              bounds.maxHeight - widget.bottomInset - top >= 200;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_configured == true)
                nativeMap
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onMapTap,
                  child: Container(
                    color: Ops.mapSurface,
                    alignment: Alignment.center,
                    child: Text(
                      _configured == null
                          ? 'Loading map…'
                          : 'Map configuration unavailable',
                      style: const TextStyle(color: Ops.textSecondary),
                    ),
                  ),
                ),
              Positioned(
                top: top,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.white,
                  elevation: 5,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 30,
                          color: Color(0xFF16233D),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                instruction,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Ops.textSecondary,
                                ),
                              ),
                              Selector<DriverSession, String?>(
                                selector: (_, session) =>
                                    session.remainingDistanceLabel,
                                builder: (context, label, _) => label == null
                                    ? const SizedBox.shrink()
                                    : Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              if (_metrics != null &&
                                  session.currentTrip?['status'] !=
                                      'in_progress')
                                Text(
                                  '${((_metrics!['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km · ${((_metrics!['durationSeconds'] as num) / 60).ceil()} min',
                                  style: const TextStyle(
                                    fontSize: 12,
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
              if (showControls)
                Positioned(
                  right: 16,
                  bottom: widget.bottomInset + 66,
                  child: FloatingActionButton.small(
                    heroTag: 'driver-route-fit',
                    tooltip: 'Show entire route',
                    backgroundColor: Colors.white,
                    foregroundColor: Ops.textPrimary,
                    onPressed: _route.length < 2
                        ? null
                        : () {
                            _follow = false;
                            _fit();
                          },
                    child: const Icon(Icons.zoom_out_map),
                  ),
                ),
              if (showControls)
                Positioned(
                  right: 16,
                  bottom: widget.bottomInset + 16,
                  child: FloatingActionButton.small(
                    heroTag: 'driver-follow',
                    backgroundColor: Colors.white,
                    foregroundColor: Ops.textPrimary,
                    tooltip: 'Recenter / follow',
                    onPressed: () async {
                      _follow = true;
                      final ok = await session.locate();
                      if (ok && session.position != null) {
                        _camera.move(
                          CameraUpdate.newLatLng(
                            LatLng(
                              session.position!.latitude,
                              session.position!.longitude,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              if (showControls &&
                  (_gpsStale ||
                      session.locationWarning != null ||
                      _error != null))
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: widget.bottomInset + 16,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _error ??
                            session.locationWarning ??
                            'Waiting for a fresh GPS location.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Ops.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
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
        if (_configured == false) const SizedBox.shrink(),
        if (_configured == true)
          SizedBox(
            key: const ValueKey('trip-native-map'),
            height: widget.compact ? 330 : 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: nativeMap,
            ),
          ),
        if (_gpsStale)
          const Text('GPS signal stale — waiting for a fresh location.'),
        if (session.locationWarning != null) Text(session.locationWarning!),
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
                      _follow = true;
                      final ok = await session.locate();
                      if (ok && session.position != null) {
                        _camera.move(
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
              label: const Text('Recenter / follow'),
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

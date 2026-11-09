import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';
import '../services/ride_request_presentation.dart';
import 'incoming_ride_request_card.dart';
import 'ongoing_ride_card.dart';

/// One coordinator for socket, polling and push hints; actions always revalidate through DriverSession.
class DriverRequestHost extends StatefulWidget {
  final Widget child;
  final RideRequestBridge? bridge;
  final void Function(String) navigate;
  final GoRouter? router;
  const DriverRequestHost({
    super.key,
    required this.child,
    this.bridge,
    this.router,
    required this.navigate,
  });
  @override
  State<DriverRequestHost> createState() => _DriverRequestHostState();
}

class _DriverRequestHostState extends State<DriverRequestHost>
    with WidgetsBindingObserver {
  late final RideRequestBridge _bridge;
  final _closed = <String>{};
  DriverSession? _session;
  Timer? _timer;
  String? _presented, _trip;
  String? _routePath;
  Map<String, dynamic>? _offer;
  bool _scheduled = false, _acting = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    _bridge = widget.bridge ?? RideRequestBridge();
    WidgetsBinding.instance.addObserver(this);
    _routePath = _currentRoutePath;
    widget.router?.routerDelegate.addListener(_routeChanged);
    _foreground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    unawaited(_bridge.initialize(_schedule));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<DriverSession>();
    if (s != _session) {
      _session?.removeListener(_schedule);
      _session = s;
      s.addListener(_schedule);
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router?.routerDelegate.removeListener(_routeChanged);
    _session?.removeListener(_schedule);
    _timer?.cancel();
    super.dispose();
  }

  String? get _currentRoutePath => widget
      .router
      ?.routerDelegate
      .currentConfiguration
      .matches
      .lastOrNull
      ?.matchedLocation;

  void _routeChanged() => scheduleMicrotask(() {
    if (!mounted) return;
    final path = _currentRoutePath;
    if (path != _routePath) setState(() => _routePath = path);
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session?.dismissRideNotifications();
    }
    _foreground = state == AppLifecycleState.resumed;
    _presented = null;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    // Paused apps do not render frames; socket delivery must still reach the
    // native overlay while another app is visible.
    scheduleMicrotask(() {
      _scheduled = false;
      if (mounted) unawaited(_sync());
    });
  }

  bool _syncing = false, _syncAgain = false;
  Future<void> _sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      await _synchronize();
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        _schedule();
      }
    }
  }

  void _navigateTrip() {
    final id = _session?.currentTrip?['id']?.toString();
    if (mounted && id != null && id != _trip) {
      _trip = id;
      widget.navigate('/driver/active-trip');
    }
  }

  Future<void> _synchronize() async {
    final s = _session;
    if (s == null || !mounted) return;
    if (!s.authenticated ||
        !s.api.hasDriverRole ||
        s.api.providerMode != 'driver') {
      if (_offer != null) {
        setState(() => _offer = null);
        await _bridge.dismiss();
      }
      return;
    }
    final trip = s.currentTrip?['id']?.toString();
    if (trip != null) {
      _timer?.cancel();
      _timer = null;
      if (_offer != null) setState(() => _offer = null);
      if (trip != _trip || _presented != null) {
        _presented = null;
        await _bridge.dismiss();
        _navigateTrip();
      }
      return;
    }
    _trip = null;
    if (!_acting && !s.busy) {
      final action = await _bridge.takeAction();
      if (action != null) {
        _acting = true;
        try {
          await s.refresh();
          final id = action['rideId']?.toString();
          final deadline = action['deadline'];
          if (id != null &&
              deadline is num &&
              deadline > DateTime.now().millisecondsSinceEpoch) {
            if (action['action'] == 'accept') {
              if (await s.accept(id)) _navigateTrip();
            } else if (action['action'] == 'reject') {
              if (await s.decline(id) && mounted) {
                widget.navigate('/driver/dashboard');
              }
            } else {
              widget.navigate(rideRequestRoute(id));
            }
          }
        } finally {
          _acting = false;
          _presented = null;
          _schedule();
        }
        return;
      }
    }
    final offers = s.rides.where(
      (r) =>
          offerRemaining(r) > Duration.zero && !_closed.contains(offerKey(r)),
    );
    final next = offers.firstOrNull;
    if (next == null) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _schedule());
    }
    final key = next == null ? null : offerKey(next);
    if (key != _presented) {
      if (_presented != null || next == null) {
        await _bridge.dismiss();
        if (next == null) s.dismissRideNotifications();
      }
      _presented = key;
      if (next != null) {
        await _bridge.present(next);
      }
    }
    if (mounted) setState(() => _offer = next);
  }

  Future<void> _act(bool accept) async {
    final s = _session, offer = _offer;
    if (s == null ||
        offer == null ||
        _acting ||
        s.busy ||
        offerRemaining(offer) <= Duration.zero) {
      return;
    }
    setState(() => _acting = true);
    try {
      final ok = accept
          ? await s.accept(offer['id'])
          : await s.decline(offer['id']);
      if (ok) {
        await _bridge.dismiss();
        if (accept) _navigateTrip();
      }
    } finally {
      if (mounted) setState(() => _acting = false);
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (active, bookingId) = context.select<DriverSession, (bool, String?)>(
      (session) => (
        session.authenticated &&
            session.api.hasDriverRole &&
            session.api.providerMode == 'driver' &&
            session.currentTrip != null,
        session.currentTrip?['bookingId']?.toString(),
      ),
    );
    final showRideLink =
        active &&
        _routePath != null &&
        !{
          '/driver/dashboard',
          '/driver/active-trip',
          '/login',
          '/otp',
        }.contains(_routePath) &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(child: widget.child),
            if (showRideLink)
              SafeArea(
                top: false,
                child: OngoingRideCard(
                  bookingId: bookingId,
                  onTap: () => widget.navigate('/driver/active-trip'),
                ),
              ),
          ],
        ),
        if (_foreground &&
            _offer != null &&
            _routePath != '/driver/ride-requests')
          Positioned.fill(
            child: Material(
              color: const Color(0x55000000),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: IncomingRideRequestCard(
                        ride: _offer!,
                        remaining: offerRemaining(_offer!),
                        busy: _acting || (_session?.busy ?? false),
                        accept: () => _act(true),
                        reject: () => _act(false),
                        close: () {
                          _closed.add(offerKey(_offer!));
                          unawaited(_bridge.dismiss());
                          _schedule();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';

class PremiumOperatingLocationPicker extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? initial;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  const PremiumOperatingLocationPicker({
    super.key,
    required this.api,
    this.initial,
    required this.onChanged,
  });
  @override
  State<PremiumOperatingLocationPicker> createState() =>
      _PremiumOperatingLocationPickerState();
}

class _PremiumOperatingLocationPickerState
    extends State<PremiumOperatingLocationPicker> {
  late final TextEditingController _address;
  LatLng? _point;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _address = TextEditingController(
      text: widget.initial?['address'] as String? ?? '',
    );
    final lat = widget.initial?['latitude'], lon = widget.initial?['longitude'];
    if (lat is num && lon is num) {
      _point = LatLng(lat.toDouble(), lon.toDouble());
    }
  }

  @override
  void dispose() {
    _generation++;
    _address.dispose();
    super.dispose();
  }

  void _publish() => widget.onChanged(
    _point == null
        ? null
        : {
            'address': _address.text.trim(),
            'latitude': _point!.latitude,
            'longitude': _point!.longitude,
          },
  );
  Future<void> _search() async {
    final address = _address.text.trim();
    if (address.length < 3) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _point = null;
    });
    _publish();
    try {
      final result = await widget.api.request(
        'POST',
        '/maps/geocode',
        body: {'address': address},
      ) as Map;
      final lat = (result['latitude'] as num).toDouble(),
          lon = (result['longitude'] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        throw const FormatException('Invalid coordinates');
      }
      if (!mounted || generation != _generation) return;
      setState(() => _point = LatLng(lat, lon));
      _publish();
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Unable to resolve this location. Check the address and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _selectPin(LatLng point) async {
    final generation = ++_generation;
    setState(() {
      _point = point;
      _address.text =
          '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      _error = null;
    });
    _publish();
    try {
      final result = await widget.api.request(
        'POST',
        '/maps/reverse-geocode',
        body: {'latitude': point.latitude, 'longitude': point.longitude},
      ) as Map;
      if (mounted && generation == _generation && result['address'] is String) {
        setState(() => _address.text = result['address'] as String);
        _publish();
      }
    } catch (_) {
      /* The explicitly selected coordinates remain authoritative. */
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _address,
        decoration: InputDecoration(
          labelText: 'Operating location in Bihar *',
          hintText: 'Enter city, area or full address',
          errorText: _error,
        ),
        onChanged: (_) {
          _generation++;
          setState(() {
            _point = null;
            _busy = false;
          });
          _publish();
        },
      ),
      TextButton.icon(
        onPressed: _busy ? null : _search,
        icon: const Icon(Icons.search),
        label: Text(_busy ? 'Finding location…' : 'Find operating location'),
      ),
      if (_point != null) ...[
        SizedBox(
          height: 180,
          child: GoogleMap(
            key: ValueKey('${_point!.latitude}:${_point!.longitude}'),
            initialCameraPosition: CameraPosition(target: _point!, zoom: 13),
            markers: {
              Marker(
                markerId: const MarkerId('operating-location'),
                position: _point!,
              ),
            },
            onTap: _selectPin,
            zoomControlsEnabled: false,
          ),
        ),
        Text(
          '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}',
        ),
      ],
      const Text(
        'Register your Premium vehicle operating location within Bihar.',
      ),
    ],
  );
}

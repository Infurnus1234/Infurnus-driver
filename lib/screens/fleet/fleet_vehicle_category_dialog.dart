import 'premium_operating_location_picker.dart';
import '../../repositories/vehicle_catalog_repository.dart';

import 'package:flutter/material.dart';

import '../../models/vehicle_category_policy.dart';
import '../../services/api_service.dart';

Future<Map<String, dynamic>?> selectFleetVehicleCategory(
  BuildContext context,
  ApiService api, {
  Map<String, dynamic>? initial,
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _VehicleCategoryDialog(api: api, initial: initial),
);

class _VehicleCategoryDialog extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? initial;
  const _VehicleCategoryDialog({required this.api, this.initial});

  @override
  State<_VehicleCategoryDialog> createState() => _VehicleCategoryDialogState();
}

class _VehicleCategoryDialogState extends State<_VehicleCategoryDialog> {
  late Future<dynamic> _catalog;
  String? _sector, _type, _error;
  Map<String, dynamic>? _operatingLocation;
  bool _selectionAvailable = false;
  int _catalogRequest = 0;

  @override
  void initState() {
    super.initState();
    _sector = widget.initial?['sector'] as String?;
    _type = widget.initial?['category'] as String?;
    final initial = widget.initial?['operatingLocation'];
    _operatingLocation = initial is Map
        ? Map<String, dynamic>.from(initial)
        : null;
    _catalog = _loadCatalog();
  }

  Future<dynamic> _loadCatalog() async {
    final request = ++_catalogRequest;
    final data = await VehicleCatalogRepository(api: widget.api).loadCatalog();
    if (mounted && request == _catalogRequest) {
      setState(
        () => _selectionAvailable = (data['types'] as List).cast<Map>().any(
          (type) =>
              type['catalogVisible'] == true &&
              type['sector'] == _sector &&
              type['code'] == _type,
        ),
      );
    }
    return data;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Vehicle category and type'),
    content: FutureBuilder<dynamic>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Vehicle configuration could not be loaded.'),
              TextButton(
                onPressed: () => setState(() {
                  _selectionAvailable = false;
                  _catalog = _loadCatalog();
                }),
                child: const Text('Retry'),
              ),
            ],
          );
        }

        final data = snapshot.data as Map;
        final sectors = List<String>.from(data['sectors'] as List)
            .where(
              (sector) =>
                  sector != 'rental' &&
                  VehicleCategoryPolicy.isSelectableSector(sector),
            )
            .toList();
        final rawTypes = (data['types'] as List).cast<Map>();
        final matches = rawTypes.where((type) {
          final s = type['sector']?.toString();
          final c = type['code']?.toString();
          return type['catalogVisible'] == true &&
              VehicleCategoryPolicy.allowsCode(s, c) &&
              s?.toLowerCase() == _sector?.toLowerCase();
        }).toList();

        // Deduplicate by composite key (sector, code)
        final seenKeys = <String>{};
        final types = <Map>[];
        for (final type in matches) {
          final sector = (type['sector'] as String? ?? '').toLowerCase();
          final code = (type['code'] as String? ?? '').toLowerCase();
          final key = '$sector:$code';
          if (code.isNotEmpty && !seenKeys.contains(key)) {
            seenKeys.add(key);
            types.add(type);
          }
        }

        final selectedType = types.any((type) => type['code'] == _type)
            ? _type
            : null;

        return SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      sectors.any(
                        (sector) =>
                            sector.toLowerCase() == _sector?.toLowerCase(),
                      )
                      ? _sector
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle category',
                  ),
                  items: sectors
                      .map(
                        (sector) => DropdownMenuItem(
                          value: sector,
                          child: Text(
                            const {
                                  'passenger': 'Rental',
                                  'rental': 'Rental',
                                  'logistics': 'Logistics',
                                  'premium': 'Premium',
                                  'service': 'Service',
                                }[sector] ??
                                sector,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _sector = value;
                    _type = null;
                    _selectionAvailable = false;
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('$_sector:$_type'),
                  initialValue: selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Configured vehicle type',
                  ),
                  items: types
                      .map(
                        (type) => DropdownMenuItem(
                          value: type['code'] as String,
                          child: Text(type['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _type = value;
                    _selectionAvailable = value != null;
                  }),
                ),
                if (_sector != null && types.isEmpty)
                  const Text(
                    'No configured types are available for this category.',
                  ),
                if (_sector == 'premium') ...[
                  const SizedBox(height: 16),
                  PremiumOperatingLocationPicker(
                    api: widget.api,
                    initial: _operatingLocation,
                    onChanged: (location) =>
                        setState(() => _operatingLocation = location),
                  ),
                ],
                if (_error != null) Text(_error!),
              ],
            ),
          ),
        );
      },
    ),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            !_selectionAvailable ||
                _sector == null ||
                _type == null ||
                (_sector == 'premium' && _operatingLocation == null)
            ? null
            : () => Navigator.pop(context, {
                'sector': _sector!,
                'category': _type!,
                if (_sector == 'premium')
                  'operatingLocation': _operatingLocation!,
              }),
        child: const Text('Continue'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../models/vehicle_category_policy.dart';
import '../../services/api_service.dart';

Future<Map<String, String>?> selectFleetVehicleCategory(
  BuildContext context,
  ApiService api, {
  Map<String, dynamic>? initial,
}) => showDialog<Map<String, String>>(
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

  @override
  void initState() {
    super.initState();
    _sector = widget.initial?['sector'] as String?;
    _type = widget.initial?['category'] as String?;
    _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
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
                onPressed: () => setState(
                  () => _catalog = widget.api.request(
                    'GET',
                    '/provider/vehicle-catalog',
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          );
        }

        final data = snapshot.data as Map;
        final sectors = List<String>.from(data['sectors'] as List)
            .where(VehicleCategoryPolicy.isSelectableSector)
            .toList();
        final rawTypes = (data['types'] as List).cast<Map>();
        final matches = rawTypes.where((type) {
          final s = type['sector']?.toString();
          final c = type['code']?.toString();
          return VehicleCategoryPolicy.allowsCode(s, c) &&
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
                          child: Text(sector),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _sector = value;
                    _type = null;
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
                  onChanged: (value) => setState(() => _type = value),
                ),
                if (_sector != null && types.isEmpty)
                  const Text(
                    'No configured types are available for this category.',
                  ),
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
        onPressed: _sector == null || _type == null
            ? null
            : () => Navigator.pop(context, {
                'sector': _sector!,
                'category': _type!,
              }),
        child: const Text('Continue'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

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
  String? _sector, _type;
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
        final sectors = List<String>.from(data['sectors'] as List);
        final types = (data['types'] as List)
            .cast<Map>()
            .where(
              (t) =>
                  t['sector'] == _sector ||
                  (_sector == 'rental' &&
                      ['passenger', 'premium'].contains(t['sector'])),
            )
            .toList();
        final selectedType = types.any((t) => t['code'] == _type)
            ? _type
            : null;
        return SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: sectors.contains(_sector) ? _sector : null,
                decoration: const InputDecoration(
                  labelText: 'Vehicle category',
                ),
                items: sectors
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _sector = v;
                  _type = null;
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_sector),
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Configured vehicle type',
                ),
                items: types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['code'] as String,
                        child: Text(t['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v),
              ),
              if (_sector != null && types.isEmpty)
                const Text(
                  'No configured types are available for this category.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sector == null || selectedType == null
                    ? null
                    : () => Navigator.pop(context, {
                        'sector': _sector!,
                        'category': selectedType,
                      }),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

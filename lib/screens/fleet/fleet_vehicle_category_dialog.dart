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
  String? _sector, _type, _city, _error;

  @override
  void initState() {
    super.initState();
    _sector = widget.initial?['sector'] as String?;
    _type = widget.initial?['category'] as String?;
    _city = widget.initial?['operatingCityId'] as String?;
    _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
  }

  Future<void> _addCustomType() async {
    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add custom vehicle type'),
        content: TextField(
          onChanged: (value) => enteredName = value,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = enteredName.trim();
              if (name.isNotEmpty) Navigator.pop(dialogContext, name);
            },
            child: const Text('Create type'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    try {
      final created = await widget.api.request(
        'POST',
        '/provider/vehicle-catalog/custom',
        body: {'sector': _sector, 'name': name},
      ) as Map;
      if (!mounted) return;
      setState(() {
        _type = created['code'] as String;
        _error = null;
        _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Could not create this type. Please retry.',
        );
      }
    }
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
        final cities = (data['operatingCities'] as List? ?? []).cast<Map>();
        final selectedCity = cities.any((c) => c['id'] == _city) ? _city : null;
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
                          child: Text(
                            sector == 'passenger' ? 'Rental fleet' : sector,
                          ),
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
                if (_sector == 'premium') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('operating-city:$_city'),
                    initialValue: selectedCity,
                    decoration: const InputDecoration(
                      labelText: 'Supported Bihar city *',
                    ),
                    items: cities
                        .map(
                          (city) => DropdownMenuItem(
                            value: city['id'] as String,
                            child: Text(city['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _city = v),
                  ),
                  if (cities.isEmpty)
                    const Text(
                      'No approved Premium cities are configured. Retry configuration before saving.',
                    ),
                ],
                if (_sector != null && _sector != 'logistics')
                  TextButton(
                    onPressed: _addCustomType,
                    child: const Text('Add custom vehicle type'),
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
        onPressed:
            _sector == null ||
                _type == null ||
                (_sector == 'premium' && _city == null)
            ? null
            : () => Navigator.pop(context, {
                'sector': _sector!,
                'category': _type!,
                if (_sector == 'premium') 'operatingCityId': _city!,
              }),
        child: const Text('Continue'),
      ),
    ],
  );
}

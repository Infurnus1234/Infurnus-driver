import 'dart:developer' as developer;

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
  final _customName = TextEditingController();
  late Future<dynamic> _catalog;
  String? _sector, _type, _error;
  bool _creating = false, _addingCustomType = false;

  @override
  void initState() {
    super.initState();
    _sector = widget.initial?['sector'] as String?;
    _type = widget.initial?['category'] as String?;
    _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
  }

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_sector == null ||
        !VehicleCategoryPolicy.isSelectableSector(_sector) ||
        _sector == 'logistics' ||
        _customName.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await widget.api.request(
        'POST',
        '/provider/vehicle-catalog/custom',
        body: {'sector': _sector, 'name': _customName.text.trim()},
      ) as Map;
      if (!mounted) return;
      setState(() {
        _type = created['code'] as String;
        _customName.clear();
        _addingCustomType = false;
        _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
      });
    } catch (e) {
      developer.log(
        'Custom vehicle type creation failed',
        name: 'VehicleCategoryDialog',
        error: e,
      );
      if (mounted) {
        setState(() => _error = 'Could not create this type. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
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
        final sectors = List<String>.from(data['sectors'] as List)
            .where(VehicleCategoryPolicy.isSelectableSector)
            .toList();
        final matches = (data['types'] as List)
            .cast<Map>()
            .where(
              (type) =>
                  (type['sector'] == _sector &&
                      VehicleCategoryPolicy.allowsType(
                        _sector,
                        type['name']?.toString(),
                      )) ||
                  (_sector == 'rental' &&
                      type['sector'] == 'premium' &&
                      VehicleCategoryPolicy.allowsType(
                        _sector,
                        type['name']?.toString(),
                      )),
            )
            .toList();
        final types = <String, Map>{
          for (final type in matches) type['code'] as String: type,
        }.values.toList();
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
                    _addingCustomType = false;
                    _customName.clear();
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
                if (_sector != null &&
                    VehicleCategoryPolicy.isSelectableSector(_sector) &&
                    _sector != 'logistics' &&
                    !_addingCustomType)
                  TextButton.icon(
                    onPressed: _creating
                        ? null
                        : () => setState(() => _addingCustomType = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Add custom vehicle type'),
                  ),
                if (_addingCustomType) ...[
                  TextField(
                    controller: _customName,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Custom vehicle type name',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _creating
                            ? null
                            : () => setState(() {
                                _addingCustomType = false;
                                _customName.clear();
                              }),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _creating || _customName.text.trim().isEmpty
                            ? null
                            : _create,
                        child: const Text('Create type'),
                      ),
                    ],
                  ),
                ],
                if (_error != null) Text(_error!),
                if (_sector != null && _sector != 'logistics')
                  const Text(
                    'Custom types are saved for your fleet. Registration does not enable pricing or dispatch.',
                  ),
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

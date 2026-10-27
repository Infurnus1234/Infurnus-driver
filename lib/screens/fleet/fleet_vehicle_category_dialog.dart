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
  String? _sector, _type, _error;
  String _search = '';
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    _sector = widget.initial?['sector'] as String?;
    _type = widget.initial?['category'] as String?;
    _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await widget.api.request(
        'POST',
        '/provider/vehicle-catalog/custom',
        body: {'sector': _sector, 'name': _search.trim()},
      ) as Map;
      if (!mounted) return;
      setState(() {
        _type = created['code'] as String;
        _search = '';
        _catalog = widget.api.request('GET', '/provider/vehicle-catalog');
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not create this type. Please retry.',
        );
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
        final sectors = List<String>.from(data['sectors'] as List);
        final matches = (data['types'] as List)
            .cast<Map>()
            .where(
              (t) =>
                  t['sector'] == _sector ||
                  (_sector == 'rental' &&
                      ['passenger', 'premium'].contains(t['sector'])),
            )
            .toList();
        final types = <String, Map>{
          for (final t in matches) t['code'] as String: t,
        }.values.toList();
        final visibleTypes = types
            .where(
              (t) => t['name'].toString().toLowerCase().contains(
                _search.toLowerCase(),
              ),
            )
            .toList();
        final selectedType = types.any((t) => t['code'] == _type)
            ? _type
            : null;
        return SizedBox(
          width: 420,
          child: SingleChildScrollView(
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
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search or enter a missing vehicle name',
                  ),
                  maxLength: 100,
                  onChanged: (v) => setState(() => _search = v),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('$_sector:$_search:$_type'),
                  initialValue:
                      visibleTypes.any((t) => t['code'] == selectedType)
                      ? selectedType
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Configured vehicle type',
                  ),
                  items: visibleTypes
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
                if (_sector != null &&
                    _search.trim().isNotEmpty &&
                    !types.any(
                      (t) =>
                          t['name'].toString().toLowerCase() ==
                          _search.trim().toLowerCase(),
                    ))
                  TextButton.icon(
                    onPressed: _creating ? null : _create,
                    icon: const Icon(Icons.add),
                    label: Text(
                      _creating ? 'Creating…' : 'Add "${_search.trim()}"',
                    ),
                  ),
                if (_error != null) Text(_error!),
                const Text(
                  'Custom types are saved for your fleet. Registration does not enable pricing or dispatch.',
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vehicle_catalog_model.dart';
import '../repositories/vehicle_catalog_repository.dart';
import '../core/theme.dart';

class VehicleSelectionSearchWidget extends StatefulWidget {
  final VehicleCatalogItem? initialSelection;
  final ValueChanged<VehicleCatalogItem> onVehicleSelected;

  const VehicleSelectionSearchWidget({
    super.key,
    this.initialSelection,
    required this.onVehicleSelected,
  });

  @override
  State<VehicleSelectionSearchWidget> createState() =>
      _VehicleSelectionSearchWidgetState();
}

class _VehicleSelectionSearchWidgetState
    extends State<VehicleSelectionSearchWidget> {
  final _searchController = TextEditingController();
  final _repository = VehicleCatalogRepository();
  Timer? _debounceTimer;

  List<VehicleCatalogItem> _suggestions = [];
  bool _isLoading = false;
  VehicleCatalogItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialSelection;
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final results = await _repository.searchVehicles(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Vehicle Display Banner
        if (_selectedItem != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: InfurnusTheme.greenLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: InfurnusTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _selectedItem!.fullName,
                            style: const TextStyle(
                              color: InfurnusTheme.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: InfurnusTheme.buttonBlack,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SELECTED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: ${_selectedItem!.category} • Fuel: ${_selectedItem!.fuelType} • Payload: ${_selectedItem!.payloadCapacity}',
                        style: const TextStyle(
                          color: InfurnusTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: InfurnusTheme.textMuted),
                  onPressed: () {
                    setState(() {
                      _selectedItem = null;
                      _searchController.clear();
                      _performSearch('');
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Vehicle Search Bar
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: InfurnusTheme.textDark),
          decoration: InputDecoration(
            labelText:
                'Search Vehicle Model (e.g. Alto, Fortuner, Tata Ace)...',
            hintText: 'Type vehicle name or brand',
            prefixIcon: const Icon(
              Icons.search,
              color: InfurnusTheme.primaryGreen,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: InfurnusTheme.textMuted,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : (_isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: InfurnusTheme.primaryGreen,
                            ),
                          ),
                        )
                      : null),
          ),
        ),
        const SizedBox(height: 12),

        // Live Suggestions List Container
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _suggestions.isEmpty && !_isLoading
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off,
                            color: InfurnusTheme.textMuted,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Type to search vehicle catalog'
                                : 'No matching vehicles found for "${_searchController.text}"',
                            style: const TextStyle(
                              color: InfurnusTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      final isSelected = _selectedItem?.id == item.id;

                      return Material(
                        color: isSelected
                            ? InfurnusTheme.greenLight
                            : Colors.white,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.local_shipping_outlined,
                            color: isSelected
                                ? InfurnusTheme.primaryGreen
                                : InfurnusTheme.textMuted,
                            size: 20,
                          ),
                          title: Text(
                            item.fullName,
                            style: TextStyle(
                              color: InfurnusTheme.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.fuelType} (${item.payloadCapacity})',
                            style: const TextStyle(
                              color: InfurnusTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: InfurnusTheme.primaryGreen,
                                  size: 18,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: InfurnusTheme.textMuted,
                                  size: 16,
                                ),
                          onTap: () {
                            setState(() {
                              _selectedItem = item;
                            });
                            widget.onVehicleSelected(item);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

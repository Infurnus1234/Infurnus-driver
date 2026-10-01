import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location_model.dart';
import '../repositories/location_catalog_repository.dart';
import '../core/theme.dart';

class LocationSearchWidget extends StatefulWidget {
  final String label;
  final String hint;
  final LocationItem? initialLocation;
  final ValueChanged<LocationItem> onLocationSelected;

  const LocationSearchWidget({
    super.key,
    this.label = 'Search Map Location / Address',
    this.hint = 'Type place name, area, or landmark...',
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationSearchWidget> createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  final _searchController = TextEditingController();
  final _repository = LocationCatalogRepository();
  Timer? _debounceTimer;

  List<LocationItem> _suggestions = [];
  bool _isLoading = false;
  LocationItem? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
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
    final results = await _repository.searchLocations(query);
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
        // Selected Location Card
        if (_selectedLocation != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: InfurnusTheme.greenLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: InfurnusTheme.primaryGreen, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLocation!.name,
                        style: const TextStyle(
                          color: InfurnusTheme.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedLocation!.address} (${_selectedLocation!.landmark})',
                        style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: InfurnusTheme.textMuted, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedLocation = null;
                      _searchController.clear();
                      _performSearch('');
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Location Search TextField
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: InfurnusTheme.textDark),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.map_outlined, color: InfurnusTheme.primaryGreen),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: InfurnusTheme.textMuted),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: InfurnusTheme.primaryGreen),
                        ),
                      )
                    : null),
          ),
        ),
        const SizedBox(height: 10),

        // Live Auto-Suggestions Box
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _suggestions.isEmpty && !_isLoading
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Type location name or area for suggestions'
                            : 'No map location suggestions found for "${_searchController.text}"',
                        style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      final isSelected = _selectedLocation?.id == item.id;

                      return Material(
                        color: isSelected ? InfurnusTheme.greenLight : Colors.white,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.place,
                            color: isSelected ? InfurnusTheme.primaryGreen : InfurnusTheme.textMuted,
                            size: 20,
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: InfurnusTheme.textDark,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${item.address} • ${item.landmark}',
                            style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: InfurnusTheme.primaryGreen, size: 18)
                              : const Icon(Icons.north_west, color: InfurnusTheme.textMuted, size: 14),
                          onTap: () {
                            setState(() {
                              _selectedLocation = item;
                            });
                            widget.onLocationSelected(item);
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/vehicle_catalog_model.dart';
import '../../widgets/vehicle_selection_search_widget.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController(text: 'KA 03 EV 4010');
  String _selectedModelName = 'Tata Ace EV Truck';
  String _category = 'Truck';
  VehicleCatalogItem? _selectedCatalogItem;

  // Track uploaded side photos
  final Map<String, bool> _photoUploads = {
    'Front View Photo': false,
    'Rear View Photo': false,
    'Left Side Photo': false,
    'Right Side Photo': false,
  };

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Add Fleet Vehicle & Photos'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Selection & Search',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Type vehicle model name (e.g. "Alto", "Fortuner", "Ford") to search suggestions.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Searchable Vehicle Selection Component
              VehicleSelectionSearchWidget(
                initialSelection: _selectedCatalogItem,
                onVehicleSelected: (item) {
                  setState(() {
                    _selectedCatalogItem = item;
                    _selectedModelName = item.fullName;
                    _category = item.category;
                  });
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Vehicle Registration Details',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _plateController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Vehicle License Plate Number',
                  prefixIcon: Icon(Icons.pin, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: Colors.white,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Category',
                  prefixIcon: Icon(Icons.category, color: InfurnusTheme.primaryGreen),
                ),
                items: ['Sedan', 'Truck', 'Van', 'Container', 'Hatchback', 'SUV'].map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 24),

              // Vehicle Photos from 3-4 Sides (New Fleet Requirement)
              const Text(
                'Vehicle Photos (3-4 Sides)',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload clear exterior photos from all sides for vehicle verification.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),

              ..._photoUploads.keys.map((sideTitle) => _photoUploadRow(sideTitle)),
              const SizedBox(height: 24),

              const Text('Vehicle Compliance Documents', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _docUploadRow('Vehicle RC Certificate'),
              const SizedBox(height: 8),
              _docUploadRow('Commercial Insurance Policy'),
              const SizedBox(height: 28),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  appState.addVehicle(
                    plateNumber: _plateController.text,
                    modelName: _selectedModelName,
                    category: _category,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vehicle "$_selectedModelName" with 4-side photos added & submitted for verification.')),
                  );
                  context.pop();
                },
                child: const Text('Submit Vehicle for Verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoUploadRow(String title) {
    final isUploaded = _photoUploads[title] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUploaded ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle : Icons.camera_alt_outlined,
                color: isUploaded ? InfurnusTheme.primaryGreen : InfurnusTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded ? InfurnusTheme.primaryGreen : InfurnusTheme.buttonBlack,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () {
              setState(() {
                _photoUploads[title] = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title uploaded successfully!')),
              );
            },
            child: Text(isUploaded ? 'Uploaded ✓' : 'Upload Photo', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _docUploadRow(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: InfurnusTheme.buttonBlack,
              side: const BorderSide(color: InfurnusTheme.buttonBlack),
              minimumSize: const Size(80, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () {},
            child: const Text('Upload PDF/Img', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

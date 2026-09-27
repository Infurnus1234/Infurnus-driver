import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController(text: 'KA 03 EV 4010');
  final _modelController = TextEditingController(text: 'Mahindra Zor Grand Cargo');
  String _category = 'Truck';

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Fleet Vehicle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vehicle Registration Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextField(
                controller: _plateController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle License Plate Number',
                  prefixIcon: Icon(Icons.pin, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _modelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model / Make Name',
                  prefixIcon: Icon(Icons.local_shipping, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: InfurnusTheme.primaryDark,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Category',
                  prefixIcon: Icon(Icons.category, color: InfurnusTheme.accentOrange),
                ),
                items: ['Sedan', 'Truck', 'Van', 'Container'].map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 24),

              const Text('Vehicle Compliance Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _docUploadRow('Vehicle RC Certificate'),
              const SizedBox(height: 8),
              _docUploadRow('Commercial Insurance Policy'),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  appState.addVehicle(
                    plateNumber: _plateController.text,
                    modelName: _modelController.text,
                    category: _category,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vehicle added and submitted for verification review.')),
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

  Widget _docUploadRow(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InfurnusTheme.primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: () {},
            child: const Text('Upload PDF/Img', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

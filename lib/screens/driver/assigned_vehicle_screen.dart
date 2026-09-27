import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class AssignedVehicleScreen extends StatelessWidget {
  const AssignedVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final vehicles = appState.vehicles;
    final vehicle = vehicles.first; // Driver's assigned vehicle

    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Vehicle Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.accentOrange, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.local_shipping, size: 36, color: InfurnusTheme.accentOrange),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: InfurnusTheme.successGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VERIFIED & ACTIVE',
                            style: TextStyle(color: InfurnusTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vehicle.modelName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registration: ${vehicle.plateNumber}',
                      style: const TextStyle(color: InfurnusTheme.accentOrange, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Category: ${vehicle.category}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Vehicle Compliance Documents',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              ...vehicle.documents.map((doc) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: InfurnusTheme.accentOrange, size: 20),
                        const SizedBox(width: 10),
                        Text(doc.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                    Text(
                      doc.status,
                      style: const TextStyle(color: InfurnusTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

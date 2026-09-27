import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class VehicleManagementScreen extends StatelessWidget {
  const VehicleManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final vehicles = appState.vehicles;

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Management')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: InfurnusTheme.accentOrange,
        onPressed: () => context.push('/fleet/add-vehicle'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add New Vehicle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: vehicles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final v = vehicles[index];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: InfurnusTheme.primaryDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: v.isActive ? InfurnusTheme.accentOrange.withOpacity(0.4) : Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(v.modelName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Switch(
                        value: v.isActive,
                        activeColor: InfurnusTheme.successGreen,
                        onChanged: (_) => appState.toggleVehicleActiveStatus(v.id),
                      ),
                    ],
                  ),
                  Text('Plate Number: ${v.plateNumber}', style: const TextStyle(color: InfurnusTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Category: ${v.category} • Status: ${v.verificationStatus}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('Assigned Driver: ${v.assignedDriverName ?? "None (Available)"}', style: TextStyle(color: v.assignedDriverName != null ? InfurnusTheme.successGreen : InfurnusTheme.warningAmber, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(100, 36)),
                        onPressed: () => context.push('/fleet/vehicle-details'),
                        child: const Text('View Documents', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final vehicle = appState.vehicles.first;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: InfurnusAppBar(title: 'Vehicle ${vehicle.plateNumber}'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.modelName, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Plate: ${vehicle.plateNumber}', style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Category: ${vehicle.category} • Status: ${vehicle.verificationStatus}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Uploaded Documents & Inspection Status', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...vehicle.documents.map((doc) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(doc.name, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(doc.status, style: const TextStyle(color: InfurnusTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 12)),
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

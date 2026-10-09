import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../core/theme.dart';

class DriverVehicleAssignmentScreen extends StatefulWidget {
  const DriverVehicleAssignmentScreen({super.key});

  @override
  State<DriverVehicleAssignmentScreen> createState() =>
      _DriverVehicleAssignmentScreenState();
}

class _DriverVehicleAssignmentScreenState
    extends State<DriverVehicleAssignmentScreen> {
  String? _selectedDriverId;
  String? _selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final approvedDrivers = appState.managedDrivers
        .where((d) => d.applicationStatus == 'Approved')
        .toList();
    final vehicles = appState.vehicles;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver ↔ Vehicle Assignment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Approved Driver to Fleet Vehicle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Assign verified drivers to available fleet vehicles for operational deployment.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Step 1: Select Approved Driver
              const Text(
                '1. Select Approved Driver',
                style: TextStyle(
                  color: InfurnusTheme.accentOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _selectedDriverId,
                dropdownColor: InfurnusTheme.primaryDark,
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Choose Approved Driver...',
                  style: TextStyle(color: Colors.grey),
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.badge,
                    color: InfurnusTheme.accentOrange,
                  ),
                ),
                items: approvedDrivers.map((d) {
                  return DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.name} (${d.phone})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedDriverId = val);
                },
              ),
              const SizedBox(height: 20),

              // Step 2: Select Fleet Vehicle
              const Text(
                '2. Select Fleet Vehicle',
                style: TextStyle(
                  color: InfurnusTheme.accentOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleId,
                dropdownColor: InfurnusTheme.primaryDark,
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Choose Fleet Vehicle...',
                  style: TextStyle(color: Colors.grey),
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.local_shipping,
                    color: InfurnusTheme.accentOrange,
                  ),
                ),
                items: vehicles.map((v) {
                  return DropdownMenuItem(
                    value: v.id,
                    child: Text('${v.modelName} - ${v.plateNumber}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedVehicleId = val);
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  if (_selectedDriverId != null && _selectedVehicleId != null) {
                    appState.assignDriverToVehicle(
                      _selectedDriverId!,
                      _selectedVehicleId!,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Successfully assigned Driver to Vehicle!',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select both an approved driver and a vehicle.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.link, size: 20),
                label: const Text('Confirm Assignment'),
              ),
              const SizedBox(height: 32),

              // Active Assignments List
              const Text(
                'Current Active Assignments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              ...approvedDrivers.map((driver) {
                return Container(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            driver.assignedVehiclePlate != null
                                ? 'Assigned: ${driver.assignedVehiclePlate}'
                                : 'Status: Unassigned',
                            style: TextStyle(
                              color: driver.assignedVehiclePlate != null
                                  ? InfurnusTheme.successGreen
                                  : InfurnusTheme.warningAmber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (driver.assignedVehiclePlate != null) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            appState.unassignDriver(driver.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unassigned driver ${driver.name}',
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Unassign',
                            style: TextStyle(
                              fontSize: 11,
                              color: InfurnusTheme.dangerRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

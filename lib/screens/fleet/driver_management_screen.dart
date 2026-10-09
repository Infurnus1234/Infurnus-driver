import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../core/theme.dart';

class DriverManagementScreen extends StatelessWidget {
  const DriverManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final drivers = appState.managedDrivers;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleet Driver Management')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: InfurnusTheme.infoBlue,
        onPressed: () => context.push('/fleet/add-driver'),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Driver Application',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: drivers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final isApproved = driver.applicationStatus == 'Approved';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: InfurnusTheme.primaryDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isApproved
                      ? InfurnusTheme.successGreen.withValues(alpha: 0.4)
                      : InfurnusTheme.warningAmber.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? InfurnusTheme.successGreen.withValues(
                                  alpha: 0.2,
                                )
                              : InfurnusTheme.warningAmber.withValues(
                                  alpha: 0.2,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          driver.applicationStatus.toUpperCase(),
                          style: TextStyle(
                            color: isApproved
                                ? InfurnusTheme.successGreen
                                : InfurnusTheme.warningAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${driver.phone} • Email: ${driver.email}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assigned Vehicle: ${driver.assignedVehiclePlate ?? "None"}',
                    style: TextStyle(
                      color: driver.assignedVehiclePlate != null
                          ? InfurnusTheme.accentOrange
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (driver.rejectionReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Admin Note: ${driver.rejectionReason}',
                      style: const TextStyle(
                        color: InfurnusTheme.dangerRed,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isApproved) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: InfurnusTheme.accentOrange,
                            minimumSize: const Size(120, 34),
                          ),
                          onPressed: () => context.push('/fleet/assignment'),
                          child: const Text(
                            'Assign Vehicle',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 34),
                          ),
                          onPressed: () =>
                              appState.adminApproveManagedDriver(driver.id),
                          child: const Text(
                            'Simulate Admin Approval',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
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

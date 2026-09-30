import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/mode_switch_header.dart';
import '../../widgets/custom_drawer.dart';

class FleetDashboardScreen extends StatelessWidget {
  const FleetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final vehicles = appState.vehicles;
    final drivers = appState.managedDrivers;
    final activeVehicles = vehicles.where((v) => v.isActive).length;
    final assignedDrivers = drivers.where((d) => d.assignedVehicleId != null).length;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Fleet Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ModeSwitchHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fleet Operations Overview',
                      style: TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    // Fleet Summary Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _fleetStatCard(
                          title: 'Total Vehicles',
                          count: '${vehicles.length}',
                          subtext: '$activeVehicles Active Fleet',
                          icon: Icons.local_shipping,
                          color: InfurnusTheme.primaryGreen,
                          onTap: () => context.push('/fleet/vehicles'),
                        ),
                        _fleetStatCard(
                          title: 'Managed Drivers',
                          count: '${drivers.length}',
                          subtext: '$assignedDrivers Assigned',
                          icon: Icons.badge,
                          color: InfurnusTheme.infoBlue,
                          onTap: () => context.push('/fleet/drivers'),
                        ),
                        _fleetStatCard(
                          title: 'Fleet Tracking',
                          count: 'Live Map',
                          subtext: 'Real-time GPS',
                          icon: Icons.map,
                          color: InfurnusTheme.primaryGreen,
                          onTap: () => context.push('/fleet/tracking'),
                        ),
                        _fleetStatCard(
                          title: 'Revenue & Wallet',
                          count: '₹ ${appState.walletBalance.toStringAsFixed(0)}',
                          subtext: 'Payouts & Earnings',
                          icon: Icons.monetization_on,
                          color: InfurnusTheme.warningAmber,
                          onTap: () => context.push('/fleet/revenue'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions - BLACK BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.push('/fleet/add-vehicle'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Vehicle'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.push('/fleet/add-driver'),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add Driver'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Fleet Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Active Fleet Vehicles', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton(
                          onPressed: () => context.push('/fleet/vehicles'),
                          child: const Text('View All', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...vehicles.map((v) => Container(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.modelName, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold)),
                              Text('Plate: ${v.plateNumber} • ${v.category}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                              Text(
                                'Driver: ${v.assignedDriverName ?? "Unassigned"}',
                                style: TextStyle(
                                  color: v.assignedDriverName != null ? InfurnusTheme.primaryGreen : InfurnusTheme.warningAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              minimumSize: const Size(60, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => context.push('/fleet/assignment'),
                            child: const Text('Assign', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fleetStatCard({
    required String title,
    required String count,
    required String subtext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                const Icon(Icons.chevron_right, color: InfurnusTheme.textMuted, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(count, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 17, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(subtext, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

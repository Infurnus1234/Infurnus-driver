import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final managedDrivers = appState.managedDrivers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / Super Admin Panel'),
        backgroundColor: InfurnusTheme.primaryNavy,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.accentOrange, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: InfurnusTheme.accentOrange, size: 36),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Super Admin Control Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('System Authorization & Driver/Vehicle Approval Hub', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Driver Verification Management (Requirement Section 6 Rule)
              const Text(
                'Driver Application Approvals (Admin Only)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Note: Fleet Owners submit drivers; only Admin / Super Admin can approve/activate drivers.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const SizedBox(height: 12),

              ...managedDrivers.map((driver) {
                final isPending = driver.applicationStatus == 'Pending Review';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: InfurnusTheme.primaryDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(driver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPending ? InfurnusTheme.warningAmber.withValues(alpha: 0.2) : InfurnusTheme.successGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              driver.applicationStatus.toUpperCase(),
                              style: TextStyle(
                                color: isPending ? InfurnusTheme.warningAmber : InfurnusTheme.successGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Phone: ${driver.phone} • Email: ${driver.email}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: InfurnusTheme.dangerRed),
                              minimumSize: const Size(90, 32),
                            ),
                            onPressed: () {
                              appState.adminRejectManagedDriver(driver.id, 'Identity documents failed verification.');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Rejected driver application for ${driver.name}')),
                              );
                            },
                            child: const Text('Reject', style: TextStyle(color: InfurnusTheme.dangerRed, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.successGreen,
                              minimumSize: const Size(100, 32),
                            ),
                            onPressed: () {
                              appState.adminApproveManagedDriver(driver.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Approved & Activated Driver ${driver.name}')),
                              );
                            },
                            child: const Text('Approve Driver', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Section 2: Pricing & Commission
              const Text('Pricing & Commission Rules', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  children: [
                    AdminConfigRow('Base Distance Rate', '₹ 25 / km'),
                    Divider(color: Colors.white12),
                    AdminConfigRow('Peak Hour Surge Pricing', '1.5x Dynamic'),
                    Divider(color: Colors.white12),
                    AdminConfigRow('Platform Fleet Commission', '12% per Ride'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Wallet & Settlement Monitoring
              const Text('Settlement & Refunds Monitoring', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.accentOrange),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All pending weekly payouts processed and settled.')),
                  );
                },
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('Batch Settle Fleet Payouts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminConfigRow extends StatelessWidget {
  final String label;
  final String val;

  const AdminConfigRow(this.label, this.val, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text(val, style: const TextStyle(color: InfurnusTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

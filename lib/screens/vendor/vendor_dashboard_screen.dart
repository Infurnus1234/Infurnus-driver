import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  final List<String> _branches = ['Bangalore Main Hub', 'Whitefield Depot', 'Peenya Logistics Yard'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Vendor Panel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Profile Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.accentOrange),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Enterprise Logistics Corp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Vendor ID: VEND-9901 • Plan: Enterprise Corporate', style: TextStyle(color: InfurnusTheme.accentOrange, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Module 1: Vendor Management (Branches)
              const Text('1. Branch Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              ..._branches.map((b) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(b, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const Text('Active Branch', style: TextStyle(color: InfurnusTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _branches.add('Electronic City Branch #${_branches.length + 1}'));
                },
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Add New Branch'),
              ),
              const SizedBox(height: 24),

              // Module 2: Delivery Operations (Bulk Booking & Scheduling)
              const Text('2. Delivery Operations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.accentOrange),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bulk Booking Dispatch Request Submitted (12 Cargo Trucks).')),
                        );
                      },
                      icon: const Icon(Icons.inventory, size: 18),
                      label: const Text('Bulk Booking'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.infoBlue),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Delivery Scheduled for Tomorrow 08:00 AM.')),
                        );
                      },
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Schedule Delivery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Module 3: Billing & Invoices
              const Text('3. Billing & Invoices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _billingRow('Invoice #INV-2026-09', '₹ 45,800.00', 'Paid'),
                    const Divider(color: Colors.white12),
                    _billingRow('Invoice #INV-2026-08', '₹ 38,200.00', 'Paid'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _billingRow(String inv, String amount, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inv, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Corporate Monthly Settlement', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(status, style: const TextStyle(color: InfurnusTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

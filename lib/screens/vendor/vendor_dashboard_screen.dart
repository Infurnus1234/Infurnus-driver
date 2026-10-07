import 'package:flutter/material.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  bool _isLoading = false;
  bool _hasError = false;
  final List<String> _branches = ['Bangalore Main Hub', 'Whitefield Depot', 'Peenya Logistics Yard'];

  void _retryFetch() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Business Vendor Panel'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: InfurnusTheme.primaryGreen))
            : _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: InfurnusTheme.dangerRed),
                          const SizedBox(height: 12),
                          const Text('Failed to load vendor enterprise data.', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.buttonBlack, foregroundColor: Colors.white),
                            onPressed: _retryFetch,
                            child: const Text('Retry Connection'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vendor Profile Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Global Enterprise Logistics Corp', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Vendor ID: VEND-9901 • Plan: Enterprise Corporate', style: TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Module 1: Vendor Management (Branches)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1. Branch Management', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                            TextButton(
                              onPressed: () {
                                setState(() => _hasError = true);
                              },
                              child: const Text('Simulate Error', style: TextStyle(color: InfurnusTheme.dangerRed, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_branches.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Text('No active branches found.', style: TextStyle(color: InfurnusTheme.textMuted)),
                            ),
                          )
                        else
                          ..._branches.map((b) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(b, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const Text('Active Branch', style: TextStyle(color: InfurnusTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: InfurnusTheme.buttonBlack,
                            side: const BorderSide(color: InfurnusTheme.buttonBlack),
                          ),
                          onPressed: () {
                            setState(() => _branches.add('Electronic City Branch #${_branches.length + 1}'));
                          },
                          icon: const Icon(Icons.add_business, size: 18),
                          label: const Text('Add New Branch'),
                        ),
                        const SizedBox(height: 24),

                        // Module 2: Delivery Operations
                        const Text('2. Delivery Operations', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                                  foregroundColor: Colors.white,
                                ),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                                  foregroundColor: Colors.white,
                                ),
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
                        const Text('3. Billing & Invoices', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _billingRow('Invoice #INV-2026-09', '₹ 45,800.00', 'Paid'),
                              const Divider(color: Color(0xFFE2E8F0)),
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
              Text(inv, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
              const Text('Corporate Monthly Settlement', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(status, style: const TextStyle(color: InfurnusTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

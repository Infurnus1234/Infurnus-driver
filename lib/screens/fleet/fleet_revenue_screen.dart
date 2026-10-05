import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class FleetRevenueScreen extends StatefulWidget {
  const FleetRevenueScreen({super.key});

  @override
  State<FleetRevenueScreen> createState() => _FleetRevenueScreenState();
}

class _FleetRevenueScreenState extends State<FleetRevenueScreen> {
  // Bank Account Form Controllers
  final _accHolderController = TextEditingController(text: 'Vikram Sharma');
  final _accNumberController = TextEditingController(text: '489123456789');
  final _ifscController = TextEditingController(text: 'HDFC0004891');
  final _bankNameController = TextEditingController(text: 'HDFC Bank');
  final _upiController = TextEditingController(text: 'vikram@hdfcbank');

  bool _bankDetailsSaved = true;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final payouts = appState.payouts;
    final txns = appState.transactions;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Revenue & Weekly Payouts'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Card (Earnings & Weekly Payout Info)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [InfurnusTheme.greenLight, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Net Earnings Balance', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '₹ ${appState.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: InfurnusTheme.greenBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.event_available, color: InfurnusTheme.primaryGreen, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Payouts are settled automatically every Monday on a weekly cycle directly to your linked bank account.',
                              style: TextStyle(color: InfurnusTheme.textDark, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bank Account Details Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Linked Bank Account for Payouts', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(
                    onPressed: () => _showBankModal(context),
                    icon: const Icon(Icons.edit, size: 16, color: InfurnusTheme.primaryGreen),
                    label: const Text('Update Bank', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_bankNameController.text, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: InfurnusTheme.greenLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('VERIFIED', style: TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Account Holder: ${_accHolderController.text}', style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 13)),
                    Text('A/C Number: **** ${_accNumberController.text.substring(_accNumberController.text.length - 4)}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 13)),
                    Text('IFSC Code: ${_ifscController.text} • UPI: ${_upiController.text}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly Payout Settlements History
              const Text('Weekly Settlement History', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...payouts.map((p) => Container(
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
                        Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Weekly Cycle • ${p.bankAccount} • Date: ${p.requestedDate}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.status == 'Settled' ? InfurnusTheme.greenLight : InfurnusTheme.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.status.toUpperCase(),
                        style: TextStyle(
                          color: p.status == 'Settled' ? InfurnusTheme.primaryGreen : InfurnusTheme.warningAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 24),

              // Transaction History
              const Text('Recent Revenue Transactions', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...txns.map((t) => Container(
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
                        Text(t.title, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(t.date, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                    Text(
                      '${t.type == "credit" ? "+" : "-"} ₹${t.amount}',
                      style: TextStyle(
                        color: t.type == 'credit' ? InfurnusTheme.successGreen : InfurnusTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

  void _showBankModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add / Update Bank Account Details', style: TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Weekly payouts are transferred directly to this verified bank account.', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: _accHolderController,
                decoration: const InputDecoration(labelText: 'Account Holder Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bank Account Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ifscController,
                decoration: const InputDecoration(labelText: 'IFSC Code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bankNameController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiController,
                decoration: const InputDecoration(labelText: 'UPI ID (Optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _bankDetailsSaved = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bank account details updated successfully for weekly payouts!')),
                  );
                },
                child: const Text('Save Bank Account Details'),
              ),
            ],
          ),
        );
      },
    );
  }
}

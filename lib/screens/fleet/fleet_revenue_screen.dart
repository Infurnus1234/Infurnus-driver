import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class FleetRevenueScreen extends StatefulWidget {
  const FleetRevenueScreen({super.key});

  @override
  State<FleetRevenueScreen> createState() => _FleetRevenueScreenState();
}

class _FleetRevenueScreenState extends State<FleetRevenueScreen> {
  final _amountController = TextEditingController(text: '2500');

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final payouts = appState.payouts;
    final txns = appState.transactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Revenue & Wallet Management')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [InfurnusTheme.primaryDark, InfurnusTheme.primaryNavy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: InfurnusTheme.accentOrange, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Wallet Balance', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '₹ ${appState.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.accentOrange),
                            onPressed: () => _showPayoutModal(context, appState),
                            icon: const Icon(Icons.account_balance, size: 18),
                            label: const Text('Request Payout'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payout Requests Section
              const Text('Payout History & Settlement Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...payouts.map((p) => Container(
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
                        Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Bank: ${p.bankAccount} • Date: ${p.requestedDate}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.status == 'Settled' ? InfurnusTheme.successGreen.withValues(alpha: 0.2) : InfurnusTheme.warningAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.status.toUpperCase(),
                        style: TextStyle(
                          color: p.status == 'Settled' ? InfurnusTheme.successGreen : InfurnusTheme.warningAmber,
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
              const Text('Recent Revenue Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              ...txns.map((t) => Container(
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
                        Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(t.date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
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

  void _showPayoutModal(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: InfurnusTheme.primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Payout Withdrawal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Payout Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Settlement Account: HDFC Bank **** 4891', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(_amountController.text) ?? 0.0;
                  appState.requestPayout(amt, 'HDFC Bank **** 4891');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payout request of ₹$amt submitted.')),
                  );
                },
                child: const Text('Confirm Payout Request'),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final txns = appState.transactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Earnings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  children: [
                    const Text('Total Wallet Balance', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '₹ ${appState.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InfurnusTheme.accentOrange,
                        minimumSize: const Size(180, 42),
                      ),
                      onPressed: () {
                        appState.requestPayout(1000.00, 'HDFC Bank **** 4891');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payout request of ₹1000 submitted.')),
                        );
                      },
                      icon: const Icon(Icons.account_balance, size: 18),
                      label: const Text('Withdraw Payout'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Recent Trip Earnings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                        fontSize: 15,
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
}

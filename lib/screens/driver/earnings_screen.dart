import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final txns = appState.transactions;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Driver Earnings'),
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
                    colors: [InfurnusTheme.greenLight, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: InfurnusTheme.primaryGreen, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text('Total Wallet Balance', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '₹ ${appState.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                        foregroundColor: Colors.white,
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

              const Text('Recent Trip Earnings', style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
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

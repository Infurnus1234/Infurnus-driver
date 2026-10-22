import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'operations.dart';

class FleetMonthlyFinance extends StatefulWidget {
  final ApiService api;
  const FleetMonthlyFinance({super.key, required this.api});
  @override
  State<FleetMonthlyFinance> createState() => _FleetMonthlyFinanceState();
}

class _FleetMonthlyFinanceState extends State<FleetMonthlyFinance> {
  late String _month;
  late List<String> _months;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _months = List.generate(24, (i) {
      final d = DateTime.utc(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    _month = _months.first;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _month,
        decoration: const InputDecoration(
          labelText: 'Reporting month (business timezone)',
        ),
        items: [
          for (final m in _months) DropdownMenuItem(value: m, child: Text(m)),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _month = v);
        },
      ),
      ApiPanel(
        embedded: true,
        api: widget.api,
        path: '/provider/fleet-finance?month=$_month',
        builder: (context, value) {
          final r = value as Map;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.containsKey('netRevenuePaise'))
                OpsPanel(
                  title: 'Paid net revenue · ${r['timeZone']}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inr(r['netRevenuePaise'])),
                      Text(
                        'Gross ${inr(r['grossRevenuePaise'])} · Successful refunds ${inr(r['refundPaise'])}',
                      ),
                    ],
                  ),
                ),
              OpsPanel(
                title: 'Completed-trip final fares',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INR ${r['final_fare_revenue'] ?? 'Unavailable'}'),
                    Text(
                      '${r['completed_trips']} completed trips; ${r['missing_final_fares']} missing final fares. Estimates are excluded.',
                    ),
                  ],
                ),
              ),
              OpsPanel(
                title: 'Bookings & payment records',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['bookings']} bookings created in this month'),
                    Text(
                      'Captured ride payments: INR ${r['captured_payments']}',
                    ),
                    const Text(
                      'This counts records currently marked CAPTURED; it is not a refund-adjusted settlement balance.',
                    ),
                    Text(
                      'Initiated/authorized payment-record amount (all time): INR ${r['unsettled_payment_amount']}',
                    ),
                    Text(
                      '${r['unsettled_payment_records']} currently unsettled payment records (all time)',
                    ),
                  ],
                ),
              ),
              OpsPanel(
                title: 'Settlement ledger',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earnings recorded: ${inr(r['earnings_paise'])}'),
                    Text('Commission recorded: ${inr(r['commission_paise'])}'),
                    Text('Net ledger entries: ${inr(r['net_ledger_paise'])}'),
                    Text(
                      'Payouts completed this month: ${inr(r['paid_payout_paise'])}',
                    ),
                    Text(
                      'Payouts pending/processing (all time): ${inr(r['pending_payout_paise'])}',
                    ),
                    const Text(
                      'Trip fares, captured payments and settlement entries are separate records. Net ledger entries are not proof of a paid payout.',
                    ),
                  ],
                ),
              ),
              for (final payment in (r['paymentHistory'] as List? ?? []))
                ListTile(
                  title: Text(
                    'INR ${payment['amount']} - ${payment['status']}',
                  ),
                  subtitle: Text(payment['created_at']?.toString() ?? ''),
                ),
              if ((r['paymentHistory'] as List? ?? []).isEmpty)
                const Text('No ride payment records created in this month.'),
            ],
          );
        },
      ),
    ],
  );
}

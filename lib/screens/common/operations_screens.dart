import 'package:flutter/material.dart';
import '../../widgets/account_details_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../core/theme.dart';
import '../../providers/driver_session.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../widgets/operations.dart';
import '../../widgets/reference_components.dart';
import '../../services/payout_request.dart';
import '../../services/api_service.dart';

class LedgerScreen extends StatefulWidget {
  final bool wallet;
  const LedgerScreen({super.key, this.wallet = false});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _period = 'daily';
  bool _requesting = false;
  int _revision = 0;
  Future<void> _payout() async {
    if (_requesting) return;
    final session = context.read<DriverSession>();
    final request = PayoutRequest(session.api);
    final controller = TextEditingController();
    setState(() => _requesting = true);
    try {
      final pending = await request.pending();
      if (!mounted) return;
      if (pending != null) {
        controller.text = ((pending['amountPaise'] as num) / 100)
            .toStringAsFixed(2);
      }
      final form = GlobalKey<FormState>();
      final paise = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            pending == null ? 'Request payout' : 'Retry pending payout',
          ),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Requires a verified bank account and sufficient wallet balance. Request acceptance does not confirm bank settlement.',
                ),
                TextFormField(
                  controller: controller,
                  readOnly: pending != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount (INR)'),
                  validator: (text) {
                    if (!RegExp(r'^\d+(\.\d{1,2})?$')
                        .hasMatch(text?.trim() ?? '')) {
                      return 'Enter a positive amount with up to 2 decimals';
                    }
                    final amount = double.tryParse(text!.trim());
                    return amount == null || amount <= 0 || amount > 99999999.99
                        ? 'Enter an amount within the supported limit'
                        : null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    (double.parse(controller.text.trim()) * 100).round(),
                  );
                }
              },
              child: const Text('Submit request'),
            ),
          ],
        ),
      );
      if (paise == null || !mounted) return;
      final result = await request.submit(paise);
      if (mounted) {
        setState(() => _revision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payout request recorded: ${result is Map ? result['status'] ?? 'pending' : 'pending'}. Check payout history for its status.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Payout could not be confirmed. Retry to reconcile the same request.',
            ),
          ),
        );
      }
    } finally {
      Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet ? 'Wallet & settlements' : 'Earnings'),
      ),
      bottomNavigationBar: session.api.providerMode == 'driver'
          ? DriverBottomNav(currentIndex: widget.wallet ? 3 : 2)
          : null,
      body: ApiPanel(
        key: ValueKey(_revision),
        api: session.api,
        path: widget.wallet ? '/provider/wallet' : '/provider/earnings',
        builder: (context, data) {
          final map = data as Map;
          if (widget.wallet) {
            final entries = map['entries'] as List? ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OpsPanel(
                  title: 'Available balance',
                  child: Text(inr(map['balancePaise']), style: Ops.metric),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Wallet ledger amounts are in INR. A payout request is not proof of bank settlement.',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/provider/payouts'),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Payout history'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/provider/bank-account'),
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Manage bank account'),
                ),
                FilledButton(
                  onPressed: _requesting ? null : _payout,
                  child: Text(
                    _requesting ? 'Checking payout request…' : 'Request payout',
                  ),
                ),
                if (entries.isEmpty)
                  const OpsEmpty('No wallet transactions yet.'),
                for (final entry in entries)
                  Card(
                    child: ListTile(
                      title: Text(
                        entry['entry_type']?.toString() ?? 'Transaction',
                      ),
                      subtitle: Text(
                        '${entry['created_at'] ?? ''}\n${entry['reference'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: Text(inr(entry['amount_paise'])),
                    ),
                  ),
              ],
            );
          }
          final periods = (map['periods'] as List? ?? [])
              .whereType<Map>()
              .toList();
          final selected = periods
              .where((r) => r['period'] == _period)
              .firstOrNull;
          final days = (map['days'] as List? ?? []).whereType<Map>().toList();
          final now = DateTime.now().toUtc();
          final today = DateTime.utc(now.year, now.month, now.day);
          final since = _period == 'daily'
              ? today
              : _period == 'weekly'
              ? today.subtract(Duration(days: today.weekday - 1))
              : DateTime.utc(now.year, now.month);
          final filtered = days.where((d) {
            final time = DateTime.tryParse(d['day']?.toString() ?? '');
            return time != null && !time.toUtc().isBefore(since);
          }).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: const InputDecoration(
                  labelText: 'Settlement period (UTC)',
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Today')),
                  DropdownMenuItem(value: 'weekly', child: Text('This week')),
                  DropdownMenuItem(value: 'monthly', child: Text('This month')),
                ],
                onChanged: (v) => setState(() => _period = v ?? 'daily'),
              ),
              const SizedBox(height: 12),
              OpsPanel(
                title: 'Net ledger earnings',
                child: Text(inr(selected?['netPaise']), style: Ops.metric),
              ),
              OpsPanel(
                title: 'Settlement breakdown',
                child: Column(
                  children: [
                    _amount('Gross earnings', selected?['grossPaise']),
                    _amount('Commission', selected?['commissionPaise']),
                    _amount('Adjustments', selected?['adjustmentPaise']),
                  ],
                ),
              ),
              if (filtered.isNotEmpty)
                OpsPanel(
                  title: 'Daily settlement net',
                  child: SettlementBars(rows: filtered.toList()),
                ),
              if (filtered.isEmpty)
                const OpsEmpty('No ledger activity in this period.'),
              for (final day in filtered)
                Card(
                  child: ListTile(
                    title: Text(day['day'].toString().split('T').first),
                    subtitle: Text(
                      'Gross ${inr(day['grossPaise'])} · Commission ${inr(day['commissionPaise'])}',
                    ),
                    trailing: Text(inr(day['netPaise'])),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _amount(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      children: [Text(label), Text(inr(value))],
    ),
  );
}

class PayoutHistoryScreen extends StatelessWidget {
  const PayoutHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payout history')),
    body: ApiPanel(
      api: context.read<DriverSession>().api,
      path: '/provider/payouts',
      builder: (context, data) => Column(
        children: [
          const OpsEmpty(
            'Payout status reflects the platform record. Confirm bank receipt independently.',
            icon: Icons.account_balance_outlined,
          ),
          if ((data as List).isEmpty) const OpsEmpty('No payout requests.'),
          for (final row in data)
            Card(
              child: ListTile(
                title: Text(inr(row['amountPaise'] ?? row['amount_paise'])),
                subtitle: Text(
                  '${row['createdAt'] ?? row['created_at'] ?? ''}',
                ),
                trailing: Text('${row['status'] ?? 'Unknown'}'),
              ),
            ),
        ],
      ),
    ),
  );
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final trips = (session.history?['rides'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Trips'),
          bottom: const TabBar(
            indicatorPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        bottomNavigationBar: const DriverBottomNav(currentIndex: 1),
        body: TabBarView(
          children: [null, 'completed', 'cancelled'].map((status) {
            final rows = trips
                .where((r) => status == null || r['status'] == status)
                .toList();
            return RefreshIndicator(
              onRefresh: () async {
                await session.refresh();
              },
              child: ListView(
                padding: const EdgeInsets.all(Ops.padding),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (session.busy) const LinearProgressIndicator(),
                  if (session.error != null)
                    OpsError(session.error!, retry: session.refresh),
                  if (rows.isEmpty) const OpsEmpty('No trips in this view.'),
                  Text('Showing ${trips.length} most recent server records.'),
                  for (final ride in rows)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ride['pickupAddress'] ?? 'Pickup unavailable'} → ${ride['destinationAddress'] ?? 'Destination unavailable'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${ride['createdAt'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Ops.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  ride['finalFare'] == null
                                      ? 'Fare unavailable'
                                      : inrRupees(ride['finalFare']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                StatusPill(
                                  ride['status']?.toString() ?? 'Unknown',
                                ),
                              ],
                            ),
                            ExpansionTile(
                              dense: true,
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                'Trip reference',
                                style: TextStyle(fontSize: 11),
                              ),
                              children: [SelectableText('Ride ${ride['id']}')],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (trips.length >= session.historyLimit &&
                      session.historyLimit < 100)
                    OutlinedButton(
                      onPressed: session.busy ? null : session.loadMoreHistory,
                      child: const Text('Load more trips'),
                    ),
                  if (trips.length >= 100)
                    const Text(
                      'The history API supports up to 100 recent trips.',
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(
        title: const Text('Personal information'),
        elevation: 0,
        backgroundColor: InfurnusTheme.bgWhite,
        foregroundColor: InfurnusTheme.textDark,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: AccountDetailsCard(),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, DriverSession session) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InfurnusTheme.r16)),
        title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: InfurnusTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.dangerRed),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await session.logout();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final name =
        '${session.providerAccount?['firstName'] ?? session.account?['firstName'] ?? session.profile?['firstName'] ?? ''} ${session.providerAccount?['lastName'] ?? session.account?['lastName'] ?? session.profile?['lastName'] ?? ''}'
            .trim();
    final displayName = name.isEmpty ? 'Driver Account' : name;
    final verificationStatus = (session.profile?['verificationStatus'] ?? session.providerAccount?['verificationStatus'] ?? 'Pending').toString().replaceAll('_', ' ');
    final upperStatus = verificationStatus.toUpperCase();
    final statusColor = (upperStatus == 'VERIFIED' || upperStatus == 'APPROVED')
        ? InfurnusTheme.primaryGreen
        : (upperStatus == 'REJECTED')
            ? InfurnusTheme.dangerRed
            : InfurnusTheme.warningAmber;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        elevation: 0,
        backgroundColor: InfurnusTheme.bgWhite,
        foregroundColor: InfurnusTheme.textDark,
      ),
      bottomNavigationBar: session.api.providerMode == 'driver'
          ? const DriverBottomNav(currentIndex: 4)
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Profile Header Card
          AppCard(
            onTap: () => context.push('/personal-details'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: InfurnusTheme.iconBoxBg,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: InfurnusTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: InfurnusTheme.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: $verificationStatus',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: InfurnusTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Preferences & Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: InfurnusTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.document_scanner_outlined,
            title: 'Application summary & documents',
            subtitle: 'View verification status and upload documents',
            onTap: () => context.push('/verification-status'),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'View your alerts and updates',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.tune_outlined,
            title: 'Notification preferences',
            subtitle: 'Choose what you want to be notified about',
            onTap: () => context.push('/settings/notifications'),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.security_outlined,
            title: 'Safety & device settings',
            subtitle: 'Permissions, SOS and device options',
            onTap: () => context.push('/safety'),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.help_outline,
            title: 'Help center',
            subtitle: 'Get support and FAQs',
            onTap: () => context.push('/support-tickets'),
          ),
          const SizedBox(height: 32),
          SettingsTile(
            icon: Icons.logout,
            title: 'Log out',
            subtitle: 'Sign out from this device',
            isDestructive: true,
            onTap: () => _confirmLogout(context, session),
          ),
        ],
      ),
    );
  }
}

class SafetySettingsScreen extends StatelessWidget {
  const SafetySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & device settings')),
      body: ListView(
        padding: const EdgeInsets.all(Ops.padding),
        children: [
          const OpsPanel(
            title: 'Emergency assistance',
            child: Text(
              'INFURNUS has no verified emergency dispatch integration. In an emergency, use your phone to contact local emergency services. Support tickets are not monitored as emergency calls.',
            ),
          ),
          OpsPanel(
            title: 'Saved emergency contact',
            child: Text(
              session.profile?['emergencyContactPhone']?.toString() ??
                  'No emergency contact returned by the server.',
            ),
          ),
          if (session.currentTrip != null)
            OpsPanel(
              title: 'Current trip',
              child: Text(
                'Ride ${session.currentTrip!['id']}\n${session.currentTrip!['pickupAddress'] ?? ''}\n${session.currentTrip!['destinationAddress'] ?? ''}',
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => Geolocator.openAppSettings(),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('App permissions & notifications'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Geolocator.openLocationSettings(),
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Location settings'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/support-tickets'),
            icon: const Icon(Icons.support_agent),
            label: const Text('Report an issue'),
          ),
        ],
      ),
    );
  }
}

class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(
      padding: const EdgeInsets.all(Ops.padding),
      children: [
        const OpsPanel(
          title: 'Notification history unavailable',
          child: Text(
            'The connected backend exposes device registration but no notification inbox or read-state API. Push alerts depend on device permission and configured delivery services.',
          ),
        ),
        OutlinedButton(
          onPressed: () => context.push('/safety'),
          child: const Text('Open notification settings'),
        ),
      ],
    ),
  );
}

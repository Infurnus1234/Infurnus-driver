import 'package:flutter/material.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../core/theme.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: InfurnusTheme.bgWhite,
        appBar: const InfurnusAppBar(title: 'My Trips', showBack: false),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: InfurnusTheme.primaryGreen,
                unselectedLabelColor: InfurnusTheme.textMuted,
                indicatorColor: InfurnusTheme.primaryGreen,
                tabs: [
                  Tab(text: 'All'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _tripList(completed: true),
                  _tripList(completed: true),
                  _tripList(completed: false),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: const DriverBottomNav(currentIndex: 1),
      ),
    );
  }

  Widget _tripList({required bool completed}) {
    final trips = [
      {'route': 'Boring Road ➔ Patna Junction', 'fare': '₹286', 'date': '18 Sep 2026, 7:20 AM', 'status': 'Completed'},
      {'route': 'Kankarbagh ➔ Fraser Road', 'fare': '₹420', 'date': '18 Sep 2026, 8:45 AM', 'status': 'Completed'},
      {'route': 'Patna City ➔ Danapur', 'fare': '₹0', 'date': '17 Sep 2026, 2:20 PM', 'status': 'Cancelled'},
      {'route': 'Kankarbagh ➔ Boring Road', 'fare': '₹310', 'date': '17 Sep 2026, 6:15 PM', 'status': 'Completed'},
    ];

    final filtered = trips.where((t) => completed ? t['status'] == 'Completed' : t['status'] == 'Cancelled').toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = filtered[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['route']!, style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(t['date']!, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: t['status'] == 'Completed' ? InfurnusTheme.greenLight : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t['status']!,
                      style: TextStyle(
                        color: t['status'] == 'Completed' ? InfurnusTheme.primaryGreen : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                t['fare']!,
                style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/operations_theme.dart';

class DriverBottomNav extends StatelessWidget {
  final int currentIndex;

  const DriverBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Ops.surfacePrimary,
      selectedItemColor: Ops.success,
      unselectedItemColor: Ops.textMuted,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.alt_route_outlined),
          activeIcon: Icon(Icons.alt_route),
          label: 'Trips',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_outlined),
          activeIcon: Icon(Icons.directions_car),
          label: 'Vehicle',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.support_agent_outlined),
          activeIcon: Icon(Icons.support_agent),
          label: 'Support',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/driver/dashboard');
            break;
          case 1:
            context.go('/driver/trips');
            break;
          case 2:
            context.push('/driver/assignment');
            break;
          case 3:
            context.push('/support-tickets');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
    );
  }
}

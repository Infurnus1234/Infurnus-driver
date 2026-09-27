import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/app_models.dart';
import '../core/theme.dart';
import 'verification_badge.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final activeMode = appState.activeMode;

    return Drawer(
      backgroundColor: InfurnusTheme.primaryDark,
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: InfurnusTheme.primaryNavy,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: InfurnusTheme.accentOrange,
              child: Text(
                user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    user?.fullName ?? 'Infurnus User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (user != null) VerificationBadge(status: user.verificationStatus),
              ],
            ),
            accountEmail: Text(
              '${user?.phone ?? ''} • ${user?.role.displayName ?? ''}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),

          // Drawer Navigation Items based on active role/mode
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Driver items
                if (user?.role == UserRole.driver ||
                    (user?.role == UserRole.driverFleetOwner && activeMode == ActiveMode.driverMode)) ...[
                  _drawerTile(
                    context: context,
                    icon: Icons.dashboard,
                    title: 'Driver Dashboard',
                    route: '/driver/dashboard',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.directions_car,
                    title: 'Ride Requests',
                    route: '/driver/rides',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.minor_crash,
                    title: 'Assigned Vehicle',
                    route: '/driver/assigned-vehicle',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.account_balance_wallet,
                    title: 'Earnings',
                    route: '/driver/earnings',
                  ),
                ],

                // Fleet Owner items
                if (user?.role == UserRole.fleetOwner ||
                    (user?.role == UserRole.driverFleetOwner && activeMode == ActiveMode.fleetOwnerMode)) ...[
                  _drawerTile(
                    context: context,
                    icon: Icons.domain,
                    title: 'Fleet Dashboard',
                    route: '/fleet/dashboard',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.local_shipping,
                    title: 'Vehicle Management',
                    route: '/fleet/vehicles',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.badge,
                    title: 'Driver Management',
                    route: '/fleet/drivers',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.link,
                    title: 'Driver-Vehicle Assignment',
                    route: '/fleet/assignment',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.map,
                    title: 'Fleet Tracking',
                    route: '/fleet/tracking',
                  ),
                  _drawerTile(
                    context: context,
                    icon: Icons.monetization_on,
                    title: 'Revenue & Wallet',
                    route: '/fleet/revenue',
                  ),
                ],

                // Common Items
                const Divider(color: Colors.white12, height: 24),

                _drawerTile(
                  context: context,
                  icon: Icons.assignment,
                  title: 'Logistics Operations',
                  route: '/logistics/bookings',
                ),
                _drawerTile(
                  context: context,
                  icon: Icons.verified,
                  title: 'Document Verification Status',
                  route: '/verification-status',
                ),
                _drawerTile(
                  context: context,
                  icon: Icons.person,
                  title: 'Provider Profile',
                  route: '/profile',
                ),
                _drawerTile(
                  context: context,
                  icon: Icons.notifications,
                  title: 'Notifications',
                  route: '/notifications',
                ),

                const Divider(color: Colors.white12, height: 24),

                // Special Panels for Business / Admin (Requirement Sections 10 & 11)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'PORTAL PANELS',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _drawerTile(
                  context: context,
                  icon: Icons.store,
                  title: 'Business Vendor Panel',
                  route: '/vendor/dashboard',
                ),
                _drawerTile(
                  context: context,
                  icon: Icons.admin_panel_settings,
                  title: 'Admin Web Panel',
                  route: '/admin/dashboard',
                ),
              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                appState.logout();
                context.go('/login');
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: InfurnusTheme.accentOrange, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}

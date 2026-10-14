import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../widgets/driver_bottom_nav.dart';
import '../../core/theme.dart';

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final name = user?.fullName.isNotEmpty == true && user?.fullName != 'New Provider User'
        ? user!.fullName
        : 'Niranjan Bhardwaj';

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Profile', showBack: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      name[0],
                      style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: InfurnusTheme.textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: InfurnusTheme.primaryGreen, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Verified Driver',
                              style: TextStyle(
                                color: InfurnusTheme.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Menu Options (Reference Screen 20)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _profileMenuItem(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      onTap: () => context.push('/personal-details'),
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle Details',
                      onTap: () => context.push('/provider-assets'),
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.description_outlined,
                      title: 'Documents',
                      badge: '3/5 Verified',
                      badgeColor: InfurnusTheme.primaryGreen,
                      onTap: () => context.push('/document-upload'),
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.account_balance_outlined,
                      title: 'Bank Details',
                      onTap: () => context.push('/driver/wallet'),
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.contact_phone_outlined,
                      title: 'Emergency Contact',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Emergency Contact: Police 112 | Infurnus SOS 1800-000-999')),
                        );
                      },
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App Settings: Notifications & Audio alerts active.')),
                        );
                      },
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () => context.push('/support'),
                    ),
                    _menuDivider(),
                    _profileMenuItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      isDestructive: true,
                      onTap: () {
                        appState.logout();
                        context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 4),
    );
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? InfurnusTheme.dangerRed : InfurnusTheme.textDark,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? InfurnusTheme.dangerRed : InfurnusTheme.textDark,
          fontSize: 14,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? InfurnusTheme.primaryGreen).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor ?? InfurnusTheme.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.chevron_right,
            color: isDestructive ? InfurnusTheme.dangerRed : const Color(0xFF94A3B8),
            size: 18,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _menuDivider() {
    return const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 16, endIndent: 16);
  }
}


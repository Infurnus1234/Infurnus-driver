import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_models.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.driverFleetOwner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Role Selection'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Account Role',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you want to operate on Infurnus.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              _roleCard(
                role: UserRole.driver,
                title: 'Driver',
                subtitle: 'Operate vehicles, accept ride requests, track earnings and delivery routes.',
                icon: Icons.directions_car,
              ),
              const SizedBox(height: 12),

              _roleCard(
                role: UserRole.driverFleetOwner,
                title: 'Driver + Fleet Owner',
                subtitle: 'Dual capabilities! Operate as an active driver AND manage a fleet of vehicles and drivers with seamless Mode Switching.',
                icon: Icons.swap_horiz_rounded,
                isRecommended: true,
              ),
              const SizedBox(height: 12),

              _roleCard(
                role: UserRole.fleetOwner,
                title: 'Fleet Owner',
                subtitle: 'Manage multiple vehicles, assign drivers, view fleet real-time tracking and revenue wallet.',
                icon: Icons.business_center,
              ),

              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final appState = Provider.of<AppState>(context, listen: false);
                  if (appState.currentUser == null) {
                    appState.register(
                      fullName: 'New Provider User',
                      email: 'provider@infurnus.com',
                      phone: '+91 98765 00000',
                      role: _selectedRole,
                    );
                  } else {
                    appState.setRole(_selectedRole);
                  }
                  context.push('/personal-details');
                },
                child: const Text('Continue to Personal Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? InfurnusTheme.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? InfurnusTheme.primaryGreen : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : InfurnusTheme.textMuted, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: InfurnusTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<UserRole>(
              value: role,
              groupValue: _selectedRole,
              activeColor: InfurnusTheme.primaryGreen,
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

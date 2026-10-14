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
                'Select Your Role',
                style: TextStyle(
                  color: InfurnusTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the role that best describes you',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              _roleCard(
                role: UserRole.driver,
                title: 'Driver',
                subtitle: 'Drive and earn with your own or assigned vehicle',
                icon: Icons.directions_car,
              ),
              const SizedBox(height: 14),

              _roleCard(
                role: UserRole.fleetOwner,
                title: 'Fleet Owner',
                subtitle: 'Manage vehicles and drivers',
                icon: Icons.business_center,
              ),
              const SizedBox(height: 14),

              _roleCard(
                role: UserRole.driverFleetOwner,
                title: 'Driver + Fleet Owner',
                subtitle: 'Drive and also manage your fleet',
                icon: Icons.swap_horiz_rounded,
                isRecommended: true,
              ),

              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final appState = Provider.of<AppState>(
                    context,
                    listen: false,
                  );
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
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
            color: isSelected
                ? InfurnusTheme.primaryGreen
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? InfurnusTheme.primaryGreen
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : InfurnusTheme.textMuted,
                size: 24,
              ),
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
                          style: const TextStyle(
                            color: InfurnusTheme.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: InfurnusTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: InfurnusTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RadioGroup<UserRole>(
              groupValue: _selectedRole,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRole = val);
                }
              },
              child: Radio<UserRole>(
                value: role,
                activeColor: InfurnusTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

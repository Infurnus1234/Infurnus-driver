import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/app_models.dart';
import '../core/theme.dart';

class ModeSwitchHeader extends StatelessWidget {
  const ModeSwitchHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    if (user == null || user.role != UserRole.driverFleetOwner) {
      return const SizedBox.shrink();
    }

    final isDriverMode = appState.activeMode == ActiveMode.driverMode;

    return Container(
      width: double.infinity,
      color: InfurnusTheme.greenLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isDriverMode ? Icons.directions_car : Icons.business_center,
                color: InfurnusTheme.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isDriverMode ? 'ACTIVE: DRIVER MODE' : 'ACTIVE: FLEET OWNER MODE',
                style: const TextStyle(
                  color: InfurnusTheme.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              appState.toggleActiveMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isDriverMode
                        ? 'Switched to Fleet Owner Mode'
                        : 'Switched to Driver Mode',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: InfurnusTheme.buttonBlack,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: InfurnusTheme.buttonBlack,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    isDriverMode ? 'Switch to Fleet Mode' : 'Switch to Driver Mode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

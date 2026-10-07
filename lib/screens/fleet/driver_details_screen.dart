import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class DriverDetailsScreen extends StatelessWidget {
  const DriverDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final driver = appState.managedDrivers.first;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: InfurnusAppBar(title: 'Driver: ${driver.name}'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: const TextStyle(color: InfurnusTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Phone: ${driver.phone}', style: const TextStyle(color: InfurnusTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('Email: ${driver.email}', style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Admin Approval Status: ${driver.applicationStatus}', style: const TextStyle(color: InfurnusTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_models.dart';
import '../../core/theme.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bizNameController;
  late TextEditingController _bizAddrController;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? 'Vikram Sharma');
    _emailController = TextEditingController(text: user?.email ?? 'vikram.sharma@infurnus.com');
    _phoneController = TextEditingController(text: user?.phone ?? '+91 98765 00112');
    _bizNameController = TextEditingController(text: user?.businessName ?? 'Vikram Fleet Services');
    _bizAddrController = TextEditingController(text: user?.businessAddress ?? 'Plot 42, Transport Nagar, Bangalore');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final role = appState.currentUser?.role ?? UserRole.driverFleetOwner;
    final isFleet = role == UserRole.fleetOwner || role == UserRole.driverFleetOwner;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(title: const Text('Personal & Business Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Profile Details',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Provide accurate identity and business registration details.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Full Name (as on Driving License / Aadhaar)',
                  prefixIcon: Icon(Icons.person_outline, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_android, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 24),

              if (isFleet) ...[
                const Divider(color: Color(0xFFE2E8F0), height: 32),
                const Text(
                  'Fleet Business Information',
                  style: TextStyle(color: InfurnusTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _bizNameController,
                  style: const TextStyle(color: InfurnusTheme.textDark),
                  decoration: const InputDecoration(
                    labelText: 'Fleet / Business Registered Name',
                    prefixIcon: Icon(Icons.business, color: InfurnusTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _bizAddrController,
                  maxLines: 2,
                  style: const TextStyle(color: InfurnusTheme.textDark),
                  decoration: const InputDecoration(
                    labelText: 'Office / Garage Operating Address',
                    prefixIcon: Icon(Icons.location_on_outlined, color: InfurnusTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  appState.updateProfile(
                    fullName: _nameController.text,
                    email: _emailController.text,
                    phone: _phoneController.text,
                    businessName: isFleet ? _bizNameController.text : null,
                    businessAddress: isFleet ? _bizAddrController.text : null,
                  );
                  context.push('/profile-photo');
                },
                child: const Text('Next: Upload Profile Photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

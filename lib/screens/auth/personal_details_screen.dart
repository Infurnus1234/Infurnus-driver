import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
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
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _vehInfoController;
  late TextEditingController _vehNumberController;
  late TextEditingController _vehTypeController;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;
    _nameController = TextEditingController(text: user?.fullName.isNotEmpty == true && user?.fullName != 'New Provider User' ? user!.fullName : '');
    _emailController = TextEditingController(text: user?.email.isNotEmpty == true && user?.email != 'provider@infurnus.com' ? user!.email : '');
    _phoneController = TextEditingController(text: user?.phone.isNotEmpty == true && user?.phone != '+91 98765 00000' ? user!.phone : '');
    _dobController = TextEditingController(text: user?.dob ?? '15/08/1992');
    _addressController = TextEditingController(text: user?.address ?? user?.businessAddress ?? '');
    _vehInfoController = TextEditingController(text: user?.vehicleInformation ?? 'Tata Ace EV Cargo');
    _vehNumberController = TextEditingController(text: user?.vehicleNumber ?? 'KA 01 EV 8899');
    _vehTypeController = TextEditingController(text: user?.vehicleType ?? 'Truck');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Driver KYC & Personal Details'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KYC & Background Verification',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete official driver and vehicle KYC details for admin review.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Full Name (as on PAN / Aadhaar / DL)',
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
              const SizedBox(height: 16),

              TextField(
                controller: _dobController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (DD/MM/YYYY)',
                  prefixIcon: Icon(Icons.cake_outlined, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _addressController,
                maxLines: 2,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Residential Address',
                  prefixIcon: Icon(Icons.location_on_outlined, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 24),

              const Divider(color: Color(0xFFE2E8F0), height: 32),
              const Text(
                'Vehicle Information (KYC)',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _vehInfoController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Make & Model Information',
                  prefixIcon: Icon(Icons.local_shipping, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _vehNumberController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Registration Number (Plate)',
                  prefixIcon: Icon(Icons.pin, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _vehTypeController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type / Category (e.g. Truck, Sedan, Bike)',
                  prefixIcon: Icon(Icons.category, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final appState = Provider.of<AppState>(context, listen: false);
                  appState.updateProfile(
                    fullName: _nameController.text,
                    email: _emailController.text,
                    phone: _phoneController.text,
                  );
                  // Update KYC specific fields in user profile
                  if (appState.currentUser != null) {
                    // Update user profile with KYC fields
                  }
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

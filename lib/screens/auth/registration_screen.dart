import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/infurnus_logo.dart';
import '../../core/theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(title: const Text('Provider Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: InfurnusLogo(iconSize: 36, fontSize: 22)),
              const SizedBox(height: 32),

              const Text(
                'Create Provider Account',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter basic details to get started with Infurnus Platform',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Mobile Phone Number',
                  prefixIcon: Icon(Icons.phone_android, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: InfurnusTheme.textDark),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined, color: InfurnusTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  context.push('/role-selection');
                },
                child: const Text('Next: Role Selection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

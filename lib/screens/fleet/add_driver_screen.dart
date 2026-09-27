import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _nameController = TextEditingController(text: 'Ramesh Patel');
  final _phoneController = TextEditingController(text: '+91 97766 55443');
  final _emailController = TextEditingController(text: 'ramesh.patel@infurnus.com');

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Fleet Driver')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Application Submission',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: InfurnusTheme.infoBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: InfurnusTheme.infoBlue),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: InfurnusTheme.infoBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Note: Driver applications require review and approval by Admin / Super Admin before vehicle assignment.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Driver Full Name',
                  prefixIcon: Icon(Icons.person, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Driver Phone Number',
                  prefixIcon: Icon(Icons.phone, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Driver Email Address',
                  prefixIcon: Icon(Icons.email, color: InfurnusTheme.accentOrange),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  appState.addDriver(
                    name: _nameController.text,
                    phone: _phoneController.text,
                    email: _emailController.text,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Driver application submitted for Admin Review.')),
                  );
                  context.pop();
                },
                child: const Text('Submit Application for Admin Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

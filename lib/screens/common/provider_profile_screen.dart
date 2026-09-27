import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_models.dart';
import '../../core/theme.dart';
import '../../widgets/verification_badge.dart';

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: InfurnusTheme.accentOrange,
                      child: Text(
                        user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'P',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? 'Provider User',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.role.displayName ?? 'Driver',
                      style: const TextStyle(color: InfurnusTheme.accentOrange, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (user != null) VerificationBadge(status: user.verificationStatus),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.primaryDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _profileDetailTile('Mobile Phone', user?.phone ?? 'N/A', Icons.phone),
                    const Divider(color: Colors.white12),
                    _profileDetailTile('Email Address', user?.email ?? 'N/A', Icons.email),
                    if (user?.businessName != null) ...[
                      const Divider(color: Colors.white12),
                      _profileDetailTile('Business Name', user!.businessName!, Icons.business),
                    ],
                    if (user?.businessAddress != null) ...[
                      const Divider(color: Colors.white12),
                      _profileDetailTile('Fleet Address', user!.businessAddress!, Icons.location_on),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () => context.push('/personal-details'),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profile & Business Info'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () => context.push('/verification-status'),
                icon: const Icon(Icons.verified, size: 18),
                label: const Text('View Document Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileDetailTile(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: InfurnusTheme.accentOrange, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

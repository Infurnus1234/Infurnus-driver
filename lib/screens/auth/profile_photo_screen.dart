import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  bool _photoCaptured = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Upload Profile Photo'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Add a clear photo of your face',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Profile Avatar with green camera badge (Reference Screen 6)
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: InfurnusTheme.primaryGreen,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _photoCaptured = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile photo captured.')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: InfurnusTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Tips Card (Reference Screen 6)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tips:',
                      style: TextStyle(
                        color: InfurnusTheme.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Use clear photo', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• Make sure your face is visible', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• Do not use sunglasses', style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                  ],
                ),
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
                  final appState = Provider.of<AppState>(context, listen: false);
                  appState.updateProfile(photoUrl: 'https://infurnus.com/photos/profile.jpg');
                  context.push('/document-upload');
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
}

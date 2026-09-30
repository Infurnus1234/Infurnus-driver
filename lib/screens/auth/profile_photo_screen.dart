import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  bool _photoCaptured = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(title: const Text('Profile Photo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Upload Profile Photo',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please take a clear selfie portrait. Face must be unobstructed for face verification.',
                textAlign: TextAlign.center,
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 36),

              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _photoCaptured ? InfurnusTheme.primaryGreen : InfurnusTheme.buttonBlack,
                      width: 3,
                    ),
                  ),
                  child: _photoCaptured
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 60, color: InfurnusTheme.primaryGreen),
                            SizedBox(height: 8),
                            Text(
                              'Photo Captured!',
                              style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 80, color: InfurnusTheme.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'No Photo Selected',
                              style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InfurnusTheme.buttonBlack,
                        side: const BorderSide(color: InfurnusTheme.buttonBlack),
                      ),
                      onPressed: () {
                        setState(() {
                          _photoCaptured = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Simulated Camera Portrait Capture.')),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Selfie'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InfurnusTheme.buttonBlack,
                        side: const BorderSide(color: InfurnusTheme.buttonBlack),
                      ),
                      onPressed: () {
                        setState(() {
                          _photoCaptured = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selected image from Gallery.')),
                        );
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final appState = Provider.of<AppState>(context, listen: false);
                  appState.updateProfile(photoUrl: 'https://infurnus.com/photos/profile.jpg');
                  context.push('/document-upload');
                },
                child: const Text('Next: Document Submission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

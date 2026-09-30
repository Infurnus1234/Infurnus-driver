import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_models.dart';
import '../../core/theme.dart';
import '../../widgets/verification_badge.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final status = user?.verificationStatus ?? VerificationStatus.draft;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(title: const Text('Application Verification Status')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              VerificationBadge(status: status),
              const SizedBox(height: 24),

              Text(
                _getStatusTitle(status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: InfurnusTheme.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _getStatusDescription(status),
                textAlign: TextAlign.center,
                style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Submitted Application Progress',
                      style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _timelineStep('Registration & Role Selection', true),
                    _timelineStep('Personal & Business Details', true),
                    _timelineStep('Identity Document Upload', true),
                    _timelineStep(
                      'Admin Verification & Review',
                      status == VerificationStatus.approved || status == VerificationStatus.underReview,
                    ),
                    _timelineStep('Platform Access Approval', status == VerificationStatus.approved),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (status == VerificationStatus.approved) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    context.go('/driver/dashboard');
                  },
                  child: const Text('Go to Provider Dashboard'),
                ),
              ] else if (status == VerificationStatus.rejected || status == VerificationStatus.changesRequired) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: InfurnusTheme.dangerRed),
                  onPressed: () {
                    context.push('/application-rejected');
                  },
                  child: const Text('View Rejection Details & Resubmit'),
                ),
              ] else ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: InfurnusTheme.buttonBlack,
                    side: const BorderSide(color: InfurnusTheme.buttonBlack),
                  ),
                  onPressed: () {
                    context.push('/document-upload');
                  },
                  child: const Text('Update Submitted Documents'),
                ),
              ],

              const SizedBox(height: 24),
              // Simulation Controls for Demo Testing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: InfurnusTheme.greenBorder),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SIMULATION CONTROLS (Demo Admin Action Trigger)',
                      style: TextStyle(color: InfurnusTheme.textDark, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => appState.adminApproveUser(),
                          child: const Text('Approve', style: TextStyle(color: InfurnusTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () => appState.adminRequestChanges('Driving License image unclear.'),
                          child: const Text('Request Changes', style: TextStyle(color: InfurnusTheme.dangerRed, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusTitle(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return 'Application Approved!';
      case VerificationStatus.underReview:
        return 'Application Under Admin Review';
      case VerificationStatus.rejected:
        return 'Application Rejected';
      case VerificationStatus.changesRequired:
        return 'Changes Required on Submission';
      default:
        return 'Documents Submitted';
    }
  }

  String _getStatusDescription(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return 'Your provider profile and documents have been verified by Admin. You can now accept rides, manage vehicles, or assign drivers.';
      case VerificationStatus.underReview:
        return 'Our Super Admin team is reviewing your uploaded documents. Verification typically takes 1-2 business hours.';
      case VerificationStatus.rejected:
        return 'Your provider application was not approved. Click below to review feedback and resubmit.';
      case VerificationStatus.changesRequired:
        return 'Admin has requested updates for specific uploaded documents before final approval.';
      default:
        return 'Please complete uploading all required documents to begin verification.';
    }
  }

  Widget _timelineStep(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? InfurnusTheme.primaryGreen : InfurnusTheme.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDone ? InfurnusTheme.textDark : InfurnusTheme.textMuted,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class ApplicationRejectedScreen extends StatelessWidget {
  const ApplicationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final docs = user?.documents ?? [];
    final rejectedDocs = docs.where((d) => d.status == 'Rejected' || d.rejectionReason != null).toList();

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Rejection & Resubmission'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: InfurnusTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: InfurnusTheme.dangerRed),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.report_problem, color: InfurnusTheme.dangerRed),
                        SizedBox(width: 8),
                        Text(
                          'Action Required by Admin Review',
                          style: TextStyle(
                            color: InfurnusTheme.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Admin reviewed your application and requested document updates before granting full operational access.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Specific Document Feedback',
                style: TextStyle(color: InfurnusTheme.textDark, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  itemCount: rejectedDocs.isNotEmpty ? rejectedDocs.length : docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = rejectedDocs.isNotEmpty ? rejectedDocs[index] : docs[index];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                doc.name,
                                style: const TextStyle(
                                  color: InfurnusTheme.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: InfurnusTheme.dangerRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Action Needed',
                                  style: TextStyle(
                                    color: InfurnusTheme.dangerRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            doc.rejectionReason ?? 'Photo is blurry or unreadable. Please upload a clear original image.',
                            style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(40),
                            ),
                            onPressed: () {
                              appState.submitDocument(
                                doc.id,
                                'https://infurnus.com/docs/resubmitted_${doc.id}.pdf',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Resubmitted ${doc.name}')),
                              );
                            },
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Re-upload Clear Document'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  appState.submitForReview();
                  context.push('/verification-status');
                },
                child: const Text('Resubmit Full Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

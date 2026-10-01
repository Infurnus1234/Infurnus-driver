import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../core/theme.dart';

class DocumentUploadScreen extends StatelessWidget {
  const DocumentUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final docs = user?.documents ?? [];

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: AppBar(title: const Text('Document Upload')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Required Documents',
                style: TextStyle(color: InfurnusTheme.textDark, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload legible photos of your official identity & operational documents.',
                style: TextStyle(color: InfurnusTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final isUploaded = doc.fileUrl != null || doc.status == 'Approved';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUploaded ? InfurnusTheme.primaryGreen : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUploaded ? Icons.task_alt : Icons.upload_file,
                            color: isUploaded ? InfurnusTheme.primaryGreen : InfurnusTheme.buttonBlack,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.name,
                                  style: const TextStyle(
                                    color: InfurnusTheme.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: ${doc.status}${doc.rejectionReason != null ? " (${doc.rejectionReason})" : ""}',
                                  style: TextStyle(
                                    color: doc.status == 'Rejected' ? InfurnusTheme.dangerRed : InfurnusTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: InfurnusTheme.buttonBlack, // BLACK BUTTON
                              foregroundColor: Colors.white,
                              minimumSize: const Size(90, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () {
                              appState.submitDocument(
                                doc.id,
                                'https://infurnus.com/docs/${doc.type.toLowerCase()}.pdf',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Uploaded ${doc.name}')),
                              );
                            },
                            child: Text(
                              isUploaded ? 'Replace' : 'Upload',
                              style: const TextStyle(fontSize: 12),
                            ),
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
                child: const Text('Submit Application for Verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

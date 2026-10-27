import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

Future<void> showPrivateDocumentPreview(
  BuildContext context,
  ApiService api,
  String path,
  String title,
) async {
  Future<List<String>?> load() async {
    try {
      final pages = await api.request('GET', '$path/pages/access-urls') as List;
      if (pages.isNotEmpty) {
        return pages.map((p) => p['accessUrl'] as String).toList();
      }
      final item = await api.request('GET', '$path/access-url');
      return [(item['accessUrl'] ?? item['url']) as String];
    } catch (_) {
      return null;
    }
  }

  var request = load();
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, update) => AlertDialog(
        title: Text('Preview $title'),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<String>?>(
            future: request,
            builder: (c, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This private file is unavailable. Check your connection and permissions, then retry.',
                    ),
                    TextButton(
                      onPressed: () => update(() {
                        request = load();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }
              final pages = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          final uri = Uri.parse(pages[i]);
                          if (!['http', 'https'].contains(uri.scheme) ||
                              !await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              )) {
                            throw const FormatException();
                          }
                        } catch (_) {
                          if (c.mounted) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to open this file. Retry to request fresh private access.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.visibility),
                      label: Text('Open private page ${i + 1}'),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

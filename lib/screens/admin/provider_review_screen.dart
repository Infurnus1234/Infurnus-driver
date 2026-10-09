import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/driver_session.dart';
import '../../models/provider_status.dart';
import '../../services/api_service.dart';

class ProviderReviewScreen extends StatefulWidget {
  const ProviderReviewScreen({super.key});
  @override
  State<ProviderReviewScreen> createState() => _ProviderReviewScreenState();
}

class _ProviderReviewScreenState extends State<ProviderReviewScreen> {
  List<Map<String, dynamic>> _requests = [];
  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _applications = [];
  bool _busy = false;
  String? _error;
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ApiService) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = context.read<DriverSession>();
      if (!session.authenticated || !session.api.isAdmin) {
        throw const ApiException('Reviewer authorization required.', 403);
      }
      await action(session.api);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to load the review. Retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run((api) async {
    final data = await api.request('GET', '/provider-approvals');
    _requests = (data as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    _details = null;
    final applications = await api.request(
      'GET',
      '/admin/drivers/applications?pageSize=100',
    );
    _applications = (applications['items'] as List)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
  });
  Future<void> _open(String id) => _run((api) async {
    _details = Map<String, dynamic>.from(
      await api.request('GET', '/provider-approvals/$id') as Map,
    );
    _reason.clear();
  });
  Future<void> _review(String status) => _run((api) async {
    if (status == 'REJECTED' && _reason.text.trim().isEmpty) {
      throw const ApiException('Enter a rejection reason.');
    }
    final target = _details!['target'] as Map;
    await api.request(
      'POST',
      '/provider-approvals/${_details!['request']['id']}/review',
      body: {
        'status': status,
        'expectedUpdatedAt': target['updated_at'],
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      },
    );
    _details = null;
    _requests = (await api.request('GET', '/provider-approvals') as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  });
  Future<void> _reviewApplication(
    Map<String, dynamic> application,
    String status,
  ) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status.replaceAll('_', ' ')),
        content: TextField(
          controller: reason,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Review reason (required for rejection / changes)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason.text.trim()),
            child: const Text('Submit review'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), reason.dispose);
    if (value == null || !mounted) return;
    await _run((api) async {
      if (status != 'APPROVED' && value.isEmpty) {
        throw const ApiException('Review reason required.');
      }
      await api.request(
        'POST',
        '/admin/drivers/applications/${application['id']}/review',
        body: {'status': status, if (value.isNotEmpty) 'reviewReason': value},
      );
    });
    if (mounted) await _load();
  }

  Future<void> _document(String id, int? page) => _run((api) async {
    final result = await api.request(
      'GET',
      '/provider-approvals/${_details!['request']['id']}/documents/$id/access-url${page == null ? '' : '?page=$page'}',
    );
    final uri = Uri.parse(result['accessUrl'] as String);
    if (uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ApiException('Cannot open this document on this device.');
    }
  });
  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider review'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: session.busy
                ? null
                : () async {
                    await session.logout();
                    if (context.mounted) context.go('/login');
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_details == null) ...[
            ExpansionTile(
              title: const Text('Driver / fleet association applications'),
              children: [
                for (final a in _applications)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            '${a['firstName']} ${a['lastName']} | ${a['partnerBusinessName']}',
                          ),
                          subtitle: Text(
                            '${statusLabel(a['status'])}\n${a['rejectionReason'] ?? ''}',
                          ),
                        ),
                        if ([
                          'PENDING',
                          'UNDER_REVIEW',
                          'CHANGES_REQUESTED',
                        ].contains(a['status']))
                          Wrap(
                            children: [
                              for (final status in [
                                'APPROVED',
                                'REJECTED',
                                'CHANGES_REQUESTED',
                              ])
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _reviewApplication(a, status),
                                  child: Text(status.replaceAll('_', ' ')),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_requests.isEmpty && !_busy)
              const Text('No pending review requests.'),
            for (final r in _requests)
              ListTile(
                title: Text('${r['request_type']} â€¢ ${r['target_type']}'),
                subtitle: Text(statusLabel(r['status'])),
                onTap: _busy ? null : () => _open(r['id'] as String),
              ),
          ] else ...[
            Text(
              '${_details!['request']['request_type']} â€¢ ${statusLabel(_details!['request']['status'])}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final key in [
              'license_number',
              'license_expiry',
              'business_name',
              'plate_number',
              'make',
              'model',
              'verification_status',
              'approval_status',
              'status',
              'rejection_reason',
            ])
              if (_details!['target'][key] != null)
                Text(
                  '${key.replaceAll('_', ' ')}: ${_details!['target'][key]}',
                ),
            for (final d in _details!['documents'] as List)
              Card(
                child: ListTile(
                  title: Text(d['document_type'].toString()),
                  subtitle: Text(
                    '${statusLabel(d['verification_status'] ?? d['status'])}\n${d['rejection_reason'] ?? ''}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _document(d['id'] as String, null),
                    child: const Text('View document'),
                  ),
                ),
              ),
            for (final d in _details!['documents'] as List)
              if ((d['pageCount'] as num? ?? 1) > 1)
                Wrap(
                  children: [
                    for (
                      var page = 1;
                      page <= (d['pageCount'] as num).toInt();
                      page++
                    )
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _document(d['id'] as String, page),
                        child: Text('${d['document_type']} — page $page'),
                      ),
                  ],
                ),
            TextField(
              controller: _reason,
              maxLength: 1000,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Review reason (required for rejection)',
              ),
            ),
            Wrap(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _review('APPROVED'),
                  child: const Text('Approve'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _review('REJECTED'),
                  child: const Text('Reject'),
                ),
              ],
            ),
            const Text(
              'Backend checks current reviewer permission, ownership, document policy, expiry, self-review and the target version before approving.',
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Back to review queue'),
            ),
          ],
        ],
      ),
    );
  }
}

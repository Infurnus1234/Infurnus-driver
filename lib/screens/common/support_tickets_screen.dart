import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/driver_session.dart';
import '../../core/operations_theme.dart';
import '../../widgets/operations.dart';

const String kSupportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'support@infurnus.com',
);

String supportRequestId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen>
    with WidgetsBindingObserver {
  Timer? _refresh;
  String? _requestId, _submissionBody;
  bool _active = true;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && !_busy) _load();
  }

  Future<void> _detail(String id) async {
    final api = context.read<DriverSession>().api;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: ApiPanel(
            api: api,
            path: '/support/tickets/${Uri.encodeComponent(id)}',
            refreshInterval: const Duration(seconds: 10),
            builder: (context, data) {
              final ticket = data as Map;
              return OpsPanel(
                title: ticket['subject']?.toString() ?? 'Support ticket',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText('${ticket['ticketNumber'] ?? ''}'),
                    Text('Status: ${ticket['status'] ?? 'Unknown'}'),
                    Text('Category: ${ticket['category'] ?? 'Unknown'}'),
                    Text('Created: ${ticket['createdAt'] ?? 'Unknown'}'),
                    Text('Updated: ${ticket['updatedAt'] ?? 'Unknown'}'),
                    const SizedBox(height: 16),
                    SelectableText(ticket['message']?.toString() ?? ''),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  final _subject = TextEditingController(), _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<Map<String, dynamic>> _tickets = [];
  bool _busy = false, _loaded = false, _creating = false;
  String? _error, _formError;
  int _page = 1;
  bool _hasNext = false;
  int? _failedPage;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _refresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted &&
          _active &&
          !_busy &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    if (!mounted) return;
    final targetPage = page ?? _page;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await context.read<DriverSession>().api.request(
        'GET',
        '/support/tickets?page=$targetPage&pageSize=25&includePagination=true',
      );
      if (mounted) {
        setState(() {
          _tickets = (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _page = targetPage;
          _hasNext = data['pagination']['hasNext'] as bool;
          _failedPage = null;
        });
      }
    } catch (e, stack) {
      developer.log(
        'Support ticket list load failed',
        name: 'SupportTicketsScreen',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _error = 'We couldn\'t load your support tickets. Please retry.';
          _failedPage = targetPage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _formError = null;
      _creating = true;
    });
    try {
      final bodyKey = '${_subject.text.trim()}\u0000${_message.text.trim()}';
      if (_submissionBody != bodyKey) {
        _submissionBody = bodyKey;
        _requestId = supportRequestId();
      }
      final ticket = await context.read<DriverSession>().api.request(
        'POST',
        '/support/tickets',
        body: {
          'requestId': _requestId,
          'category': 'App',
          'subject': _subject.text.trim(),
          'message': _message.text.trim(),
        },
      );
      _requestId = null;
      _submissionBody = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ticket['ticketNumber']} · ${ticket['status']}'),
          ),
        );
      }
      _subject.clear();
      _message.clear();
      if (mounted) await _load(page: 1);
    } catch (e, stack) {
      developer.log(
        'Support ticket creation failed',
        name: 'SupportTicketsScreen',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(
          () => _formError = 'We couldn\'t create your ticket. Please retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Support tickets'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Ops.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Ops.surfaceOverlay,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Ops.success,
                  size: 22,
                ),
              ),
              title: const Text(
                'Email Support',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                '$kSupportEmail · Reach our team directly',
                style: TextStyle(color: Ops.textSecondary, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Ops.textSecondary,
              ),
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: kSupportEmail,
                  queryParameters: {'subject': 'Infurnus Driver App Support'},
                );
                try {
                  final launched = await launchUrl(uri);
                  if (!launched) {
                    await Clipboard.setData(
                      const ClipboardData(text: kSupportEmail),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not open email client. Email address copied to clipboard.',
                          ),
                        ),
                      );
                    }
                  }
                } catch (_) {
                  await Clipboard.setData(
                    const ClipboardData(text: kSupportEmail),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open email client. Email address copied to clipboard.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subject,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  helperText: 'Required · 3–200 characters',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters'
                    : null,
              ),
              TextFormField(
                controller: _message,
                maxLength: 5000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue *',
                  helperText: 'Required · 5–5,000 characters',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 5
                    ? 'Enter at least 5 characters'
                    : null,
              ),
              ElevatedButton(
                onPressed: _busy ? null : _create,
                child: Text(_creating ? 'Creating ticket…' : 'Create ticket'),
              ),
            ],
          ),
        ),
        if (_formError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _formError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _create,
                child: const Text('Retry'),
              ),
            ],
          ),
        if (_busy || !_loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          OpsError(_error!, retry: () => _load(page: _failedPage))
        else if (_tickets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No support tickets yet.'),
          ),
        const SizedBox(height: 20),
        if (!_busy && _error == null && _tickets.isNotEmpty)
          ..._tickets.map(
            (t) => Card(
              child: ListTile(
                onTap: () => _detail(t['id'] as String),
                title: Text(t['subject'].toString()),
                subtitle: Text(
                  'ID ${t['ticketNumber']} · ${t['status']}\nLatest update: ${t['updatedAt'] ?? t['createdAt'] ?? 'Unknown'}\n${t['message']}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        if (!_busy && _tickets.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy || _error != null || _page == 1
                    ? null
                    : () {
                        _load(page: _page - 1);
                      },
                child: const Text('Previous'),
              ),
              Text('Page $_page'),
              TextButton(
                onPressed: _busy || _error != null || !_hasNext
                    ? null
                    : () {
                        _load(page: _page + 1);
                      },
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    ),
  );
}

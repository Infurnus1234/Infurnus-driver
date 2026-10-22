import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/driver_session.dart';
import '../../widgets/operations.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
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
  bool _busy = false;
  String? _error;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await context.read<DriverSession>().api.request(
        'GET',
        '/support/tickets?page=$_page&pageSize=25',
      );
      if (mounted) {
        setState(
          () => _tickets = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<DriverSession>().api.request(
        'POST',
        '/support/tickets',
        body: {
          'category': 'App',
          'subject': _subject.text.trim(),
          'message': _message.text.trim(),
        },
      );
      _subject.clear();
      _message.clear();
      _page = 1;
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subject,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Enter at least 3 characters'
                    : null,
              ),
              TextFormField(
                controller: _message,
                maxLength: 5000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 5
                    ? 'Enter at least 5 characters'
                    : null,
              ),
              ElevatedButton(
                onPressed: _busy ? null : _create,
                child: const Text('Create ticket'),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 20),
        if (!_busy && _tickets.isEmpty)
          const Text('No support tickets on this page.'),
        ..._tickets.map(
          (t) => Card(
            child: ListTile(
              onTap: () => _detail(t['id'] as String),
              title: Text(t['subject'].toString()),
              subtitle: Text(
                '${t['ticketNumber']} · ${t['status']}\n${t['message']}',
              ),
              isThreeLine: true,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy || _page == 1
                  ? null
                  : () {
                      _page--;
                      _load();
                    },
              child: const Text('Previous'),
            ),
            Text('Page $_page'),
            TextButton(
              onPressed: _busy || _tickets.length < 25
                  ? null
                  : () {
                      _page++;
                      _load();
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

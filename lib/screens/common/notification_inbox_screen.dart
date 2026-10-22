import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/operations.dart';

class ServerNotificationInbox extends StatefulWidget {
  const ServerNotificationInbox({super.key});
  @override
  State<ServerNotificationInbox> createState() =>
      _ServerNotificationInboxState();
}

class _ServerNotificationInboxState extends State<ServerNotificationInbox> {
  final List<Map<String, dynamic>> _items = [];
  bool _busy = false, _more = true;
  int _unread = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final offset = more ? _items.length : 0;
      final result = await context.read<DriverSession>().api.request(
        'GET',
        '/notifications/inbox?limit=25&offset=$offset',
      ) as Map;
      final rows = (result['items'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (mounted) {
        setState(() {
          if (!more) _items.clear();
          for (final row in rows) {
            if (!_items.any((old) => old['id'] == row['id'])) _items.add(row);
          }
          _unread = (result['unreadCount'] as num).toInt();
          _more = rows.length == 25;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException && e.status == 404
              ? 'Notifications are unavailable in this environment. Please contact support or try again later.'
              : e is ApiException
              ? e.message
              : 'Notification history could not be loaded.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _read(Map<String, dynamic>? item) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = context.read<DriverSession>();
      await session.api.request(
        'PATCH',
        item == null
            ? '/notifications/inbox/read-all'
            : '/notifications/inbox/${Uri.encodeComponent(item['id'] as String)}/read',
      );
      if (!mounted) return;
      setState(() {
        if (item == null) {
          for (final row in _items) {
            row['readAt'] ??= DateTime.now().toUtc().toIso8601String();
          }
          _unread = 0;
        } else if (item['readAt'] == null) {
          item['readAt'] = DateTime.now().toUtc().toIso8601String();
          if (_unread > 0) _unread--;
        }
      });
      final payload = item?['payload'];
      final route = payload is Map
          ? notificationDestination(Map<String, dynamic>.from(payload))
          : null;
      if (route != null && mounted && session.authenticated) {
        context.push(route);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to mark notification as read.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Notifications · $_unread unread'),
      actions: [
        IconButton(
          tooltip: 'Mark all as read',
          onPressed: _busy || _unread == 0 ? null : () => _read(null),
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Ops.padding),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) OpsError(_error!, retry: _load),
          if (!_busy && _error == null && _items.isEmpty)
            const OpsEmpty('No notifications yet.'),
          for (final item in _items)
            Card(
              child: ListTile(
                leading: Icon(
                  item['readAt'] == null
                      ? Icons.mark_email_unread_outlined
                      : Icons.drafts_outlined,
                ),
                title: Text(
                  item['title']?.toString() ?? 'Notification',
                  style: TextStyle(
                    fontWeight: item['readAt'] == null
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${item['body'] ?? ''}\n${item['createdAt'] ?? ''}',
                ),
                isThreeLine: true,
                onTap: _busy ? null : () => _read(item),
              ),
            ),
          if (_more && _items.isNotEmpty)
            OutlinedButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Load more'),
            ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../services/api_service.dart';
import '../../widgets/operations.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  Map? _preferences;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save({String? field, bool? value}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<DriverSession>().api;
      final result = await api.request(
        field == null ? 'GET' : 'PATCH',
        '/users/${Uri.encodeComponent(api.userId ?? '')}/preferences',
        body: field == null ? null : {field: value},
      );
      if (mounted) setState(() => _preferences = result as Map);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Preferences could not be confirmed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: ListView(
      padding: const EdgeInsets.all(Ops.padding),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) OpsError(_error!, retry: _save),
        if (_preferences != null)
          for (final field in {
            'pushNotificationsEnabled': 'Push notifications',
            'emailNotificationsEnabled': 'Email notifications',
            'smsNotificationsEnabled': 'SMS notifications',
          }.entries)
            Card(
              child: SwitchListTile(
                title: Text(field.value),
                subtitle: Text(
                  _preferences![field.key] is bool
                      ? 'Account preference'
                      : 'Not provided by server',
                ),
                value: _preferences![field.key] == true,
                onChanged: _busy || _preferences![field.key] is! bool
                    ? null
                    : (value) => _save(field: field.key, value: value),
              ),
            ),
        const OpsEmpty(
          'Your account preferences and phone notification permissions both affect delivery.',
          icon: Icons.info_outline,
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/operations_theme.dart';
import '../../providers/driver_session.dart';
import '../../services/api_service.dart';
import '../../services/ride_request_presentation.dart';
import '../../widgets/operations.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final RideRequestBridge? bridge;
  const NotificationPreferencesScreen({super.key, this.bridge});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final RideRequestBridge _bridge;
  Map? _preferences;
  Map? _bridgeStatus;
  bool _silentAlerts = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _bridge = widget.bridge ?? RideRequestBridge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _save();
      _loadBridgeStatus();
    });
  }

  Future<void> _loadBridgeStatus() async {
    final status = await _bridge.status();
    if (mounted) {
      setState(() {
        _bridgeStatus = status;
        _silentAlerts = status?['silentAlerts'] != false;
      });
    }
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
        Card(
          child: SwitchListTile(
            title: const Text('Play ride alerts even in silent mode'),
            subtitle: const Text(
              'Uses alarm audio stream to alert on incoming requests when phone is on silent or vibrate',
            ),
            value: _silentAlerts,
            onChanged: (val) async {
              await _bridge.setPlayAlertsInSilentMode(val);
              setState(() => _silentAlerts = val);
            },
          ),
        ),
        if (_bridgeStatus?['alarmVolumeZero'] == true)
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Alarm volume is currently set to zero. Increase alarm volume in device settings to hear ride alerts.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_bridgeStatus != null && _bridgeStatus!['dndAccess'] != true)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Do Not Disturb access (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Allow ride alerts to sound when Do Not Disturb is active.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await _bridge.requestDndAccess();
                      await _loadBridgeStatus();
                    },
                    child: const Text('Open settings'),
                  ),
                ],
              ),
            ),
          ),
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

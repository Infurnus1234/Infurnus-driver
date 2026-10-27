import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';
import '../services/customer_contact_launcher.dart';

class RideCustomerContactCard extends StatefulWidget {
  final Future<bool> Function(Uri)? launcher;
  const RideCustomerContactCard({super.key, this.launcher});

  @override
  State<RideCustomerContactCard> createState() =>
      _RideCustomerContactCardState();
}

class _RideCustomerContactCardState extends State<RideCustomerContactCard>
    with WidgetsBindingObserver {
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final session = context.read<DriverSession>();
    if (state == AppLifecycleState.resumed) {
      session.refreshCustomerContact();
    } else {
      session.hideCustomerContact();
    }
  }

  Future<void> _open(String scheme) async {
    if (_launching) return;
    setState(() => _launching = true);
    var opened = false;
    try {
      final uri = await context.read<DriverSession>().customerContactUri(
        scheme,
      );
      if (!mounted) return;
      if (uri != null) {
        opened =
            await (widget.launcher?.call(uri) ?? launchCustomerContactUri(uri));
      }
    } catch (_) {
      // Never log the URI/number or automatically place calls/send messages.
    } finally {
      if (mounted) {
        setState(() => _launching = false);
        if (!opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                scheme == 'tel'
                    ? 'Could not open the dialer. Refresh customer contact and try again.'
                    : 'Could not open a messaging app. Refresh customer contact and try again.',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    if (!session.canRequestCustomerContact) return const SizedBox.shrink();
    final contact = session.customerContact;
    final enabled =
        !session.busy &&
        !session.customerContactLoading &&
        !_launching &&
        contact?.phone != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (session.customerContactLoading) ...[
            const LinearProgressIndicator(
              semanticsLabel: 'Verifying customer contact',
            ),
            const SizedBox(height: 6),
            const Text('Verifying customer contact…'),
          ] else if (session.customerContactError != null) ...[
            Text(session.customerContactError!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _launching ? null : session.refreshCustomerContact,
                child: const Text('Retry customer contact'),
              ),
            ),
          ] else if (contact != null) ...[
            Text(contact.name.isEmpty ? 'Customer' : contact.name),
            const SizedBox(height: 4),
            if (contact.phone != null)
              SelectableText(contact.phone!)
            else
              const Text('No phone number is available for this customer.'),
          ] else
            const Text(
              'Customer contact is not available. Refresh the ride to retry.',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? () => _open('tel') : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? () => _open('sms') : null,
                icon: const Icon(Icons.message_outlined),
                label: const Text('Message'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

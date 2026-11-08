import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/driver_session.dart';
import '../services/customer_contact_launcher.dart';
import '../services/ride_request_presentation.dart' show driverDropAddress;

class RideCustomerContactCard extends StatefulWidget {
  final Future<bool> Function(Uri)? launcher;
  final bool compact;
  const RideCustomerContactCard({
    super.key,
    this.launcher,
    this.compact = false,
  });

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
    final (
      allowed,
      name,
      callingNumber,
      bookingId,
      address,
      loading,
      error,
      busy,
    ) = context.select((DriverSession s) {
      final trip = s.currentTrip;
      final contact = s.activeCustomerContact;
      return (
        s.canRequestCustomerContact,
        contact?.name,
        contact?.callingNumber,
        trip?['bookingId'],
        trip?['sector'] == 'logistics' && trip != null
            ? driverDropAddress(trip) ?? 'Available after PIN verification'
            : trip?['pickupAddress']?.toString() ?? 'Pickup',
        s.customerContactLoading && contact == null,
        s.customerContactError,
        s.busy,
      );
    });
    if (!allowed) return const SizedBox.shrink();
    final session = context.read<DriverSession>();
    final enabled = !busy && !_launching && callingNumber != null;
    if (widget.compact) {
      return Row(
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFFE8EDF5),
            child: Icon(Icons.person, color: Color(0xFF16233D)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Customer' : name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (bookingId != null)
                  Text(
                    "Booking ID: $bookingId",
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 3),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Call',
            onPressed: enabled ? () => _open('tel') : null,
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Message',
            onPressed: enabled ? () => _open('sms') : null,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (loading) ...[
            const LinearProgressIndicator(
              semanticsLabel: 'Verifying customer contact',
            ),
            const SizedBox(height: 6),
            const Text('Verifying customer contact…'),
          ] else if (error != null) ...[
            Text(error),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _launching ? null : session.refreshCustomerContact,
                child: const Text('Retry customer contact'),
              ),
            ),
          ] else if (name != null) ...[
            Text(name.isEmpty ? 'Customer' : name),
            const SizedBox(height: 4),
            if (bookingId != null) SelectableText("Booking ID: $bookingId"),
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

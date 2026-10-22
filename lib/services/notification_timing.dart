/// Bounded, account-lifetime diagnostics. No payloads, tokens or personal data.
/// Local presentation requests are not proof of on-screen display.
class NotificationTiming {
  final Map<String, Map<String, DateTime>> samples = {};
  final DateTime Function() clock;
  NotificationTiming({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  void record(Map<String, dynamic> data, String stage, {String? fallbackId}) {
    final id = data['notificationId'] is String
        ? data['notificationId'] as String
        : fallbackId;
    if (id == null || id.isEmpty) return;
    final sample = samples.putIfAbsent(id, () => {});
    sample.putIfAbsent(stage, () => clock().toUtc());
    final occurred = DateTime.tryParse(
      data['eventOccurredAt']?.toString() ?? '',
    );
    if (occurred != null) {
      sample.putIfAbsent('businessEventAt', () => occurred.toUtc());
    }
    while (samples.length > 100) {
      samples.remove(samples.keys.first);
    }
  }

  void clear() => samples.clear();
}

bool notificationOfferExpired(Map<String, dynamic> data, {DateTime? now}) {
  final value = data['expiresAt'];
  if (value == null) return false;
  final expiry = DateTime.tryParse(value.toString());
  return expiry == null || !expiry.isAfter((now ?? DateTime.now()).toUtc());
}

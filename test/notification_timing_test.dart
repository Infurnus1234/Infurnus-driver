import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/services/notification_timing.dart';

void main() {
  test('expired and malformed offers suppress foreground presentation', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    expect(
      notificationOfferExpired({'expiresAt': '2026-10-20T12:00:00Z'}, now: now),
      isTrue,
    );
    expect(
      notificationOfferExpired({'expiresAt': 'invalid'}, now: now),
      isTrue,
    );
    expect(
      notificationOfferExpired({'expiresAt': '2026-10-20T12:00:20Z'}, now: now),
      isFalse,
    );
    expect(notificationOfferExpired({}, now: now), isFalse);
  });
  test('timing records actual observed stages once, bounded and clearable', () {
    var clock = DateTime.utc(2026, 10, 20, 12);
    final timing = NotificationTiming(clock: () => clock);
    timing.record({'notificationId': 'fixture'}, 'foregroundReceivedAt');
    clock = clock.add(const Duration(milliseconds: 15));
    timing.record({'notificationId': 'fixture'}, 'foregroundReceivedAt');
    timing.record({
      'notificationId': 'fixture',
    }, 'localPresentationRequestedAt');
    final sample = timing.samples['fixture']!;
    expect(
      sample['localPresentationRequestedAt']!
          .difference(sample['foregroundReceivedAt']!)
          .inMilliseconds,
      15,
    );
    expect(sample.containsKey('displayedAt'), isFalse);
    for (var i = 0; i < 120; i++) {
      timing.record({'notificationId': 'fixture-$i'}, 'openedAt');
    }
    expect(timing.samples, hasLength(100));
    timing.clear();
    expect(timing.samples, isEmpty);
  });
}

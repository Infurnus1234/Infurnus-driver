import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:infurnus_driver/router/app_router.dart';

void main() {
  test('Fleet tracking and fleet subroutes are registered in appRouter', () {
    final router = createAppRouter();
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toSet();

    expect(paths.contains('/fleet/tracking'), isTrue);
    expect(paths.contains('/fleet/vehicles'), isTrue);
    expect(paths.contains('/fleet/drivers'), isTrue);
    expect(paths.contains('/fleet/assignment'), isTrue);
    expect(paths.contains('/fleet/revenue'), isTrue);
    expect(paths.contains('/fleet/dashboard'), isTrue);
  });
}

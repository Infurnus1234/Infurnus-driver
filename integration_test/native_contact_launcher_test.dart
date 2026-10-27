import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:infurnus_driver/services/customer_contact_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native customer contact opens a compose interface', (
    tester,
  ) async {
    // Reserved fictional NANP number. This probe never calls or sends a message.
    // Backend ownership/number selection is covered separately by real DB tests.
    const scheme = String.fromEnvironment(
      'CONTACT_PROBE_ACTION',
      defaultValue: 'tel',
    );
    expect(['tel', 'sms'], contains(scheme));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Customer contact native launcher verification'),
          ),
        ),
      ),
    );
    final result = await launchCustomerContactUri(
      Uri(scheme: scheme, path: '+16505550100'),
    );
    expect(result, isTrue);
  });
}
